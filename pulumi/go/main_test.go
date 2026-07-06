package main

import (
	"encoding/json"
	"strings"
	"sync"
	"testing"

	"github.com/pulumi/pulumi/sdk/v3/go/common/resource"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/stretchr/testify/assert"
)

type mocks int

func (mocks) NewResource(args pulumi.MockResourceArgs) (string, resource.PropertyMap, error) {
	outputs := args.Inputs.Copy()
	outputs["arn"] = resource.NewStringProperty("arn:aws:iam::123456789012:" + args.TypeToken + "/" + args.Name)
	return args.Name + "_id", outputs, nil
}

func (mocks) Call(args pulumi.MockCallArgs) (resource.PropertyMap, error) {
	// aws.GetPartition() — return a non-commercial partition so the test proves
	// the policy ARNs are rewritten dynamically rather than left as `aws`.
	return resource.NewPropertyMapFromMap(map[string]interface{}{
		"partition": "aws-us-gov",
	}), nil
}

func TestEntDeployRole(t *testing.T) {
	err := pulumi.RunErr(func(ctx *pulumi.Context) error {
		cfg := map[string]string{
			"ent-deploy-role:entAwsAccountArn": "arn:aws:iam::123456789012:root",
		}
		cfgJSON, _ := json.Marshal(cfg)
		ctx.Log.Debug("config: "+string(cfgJSON), nil)

		resources, err := deploy(ctx, "arn:aws:iam::123456789012:root", "HomeProdAssumeAdmin", "/", "desc", map[string]string{})
		if err != nil {
			return err
		}

		// The permission set is split across four functional managed policies, all attached to the role.
		assert.Equal(t, 4, len(resources.Policies))

		var wg sync.WaitGroup
		wg.Add(4)

		// Assert the four functional policy names (order-independent).
		policyNames := make([]interface{}, 0, len(resources.Policies))
		for _, p := range resources.Policies {
			policyNames = append(policyNames, p.Name)
		}
		pulumi.All(policyNames...).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			got := make([]string, 0, len(v))
			for _, n := range v {
				got = append(got, n.(string))
			}
			assert.ElementsMatch(t, []string{
				"EntHomeAccessCompute",
				"EntHomeAccessData",
				"EntHomeAccessSecurity",
				"EntHomeAccessPlatform",
			}, got)
			return nil
		})

		pulumi.All(resources.Role.Name).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Equal(t, "HomeProdAssumeAdmin", v[0].(string))
			return nil
		})

		pulumi.All(resources.Role.AssumeRolePolicy).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.True(t, strings.Contains(v[0].(string), "arn:aws:iam::123456789012:root"))
			return nil
		})

		// The S3 statement lives in the Data & Storage functional policy (index 1). Assert its ARNs
		// are rewritten to the deploy partition rather than left as the commercial `aws` partition.
		pulumi.All(resources.Policies[1].Policy).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Contains(t, v[0].(string), "arn:aws-us-gov:s3:::")
			return nil
		})

		wg.Wait()
		return nil
	}, pulumi.WithMocks("project", "stack", mocks(0)))

	assert.NoError(t, err)
}
