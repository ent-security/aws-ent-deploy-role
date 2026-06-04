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

		var wg sync.WaitGroup
		wg.Add(4)

		pulumi.All(resources.Policy.Name).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Equal(t, "EntHomeAccess", v[0].(string))
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

		pulumi.All(resources.Policy.Policy).ApplyT(func(v []interface{}) error {
			defer wg.Done()
			assert.Contains(t, v[0].(string), "arn:aws-us-gov:s3:::")
			return nil
		})

		wg.Wait()
		return nil
	}, pulumi.WithMocks("project", "stack", mocks(0)))

	assert.NoError(t, err)
}
