package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws/iam"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

type deployed struct {
	Policy *iam.Policy
	Role   *iam.Role
}

const (
	defaultEntAwsAccountArn = "arn:aws:iam::000000000000:root"
	defaultRoleName         = "HomeProdAssumeAdmin"
	defaultRolePath         = "/"
	defaultRoleDescription  = "Role that allows Ent Home to assume AdministratorAccess role"
	policyName              = "EntHomeAccess"
	policyDescription       = "Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts."
)

func readRepoFile(name string) (string, error) {
	// Resolve repo root: pulumi/go/ -> pulumi/ -> repo root
	exe, err := os.Getwd()
	if err != nil {
		return "", err
	}
	repoRoot := filepath.Join(exe, "..", "..")
	data, err := os.ReadFile(filepath.Join(repoRoot, name))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func deploy(
	ctx *pulumi.Context,
	entAwsAccountArn string,
	roleName string,
	rolePath string,
	roleDescription string,
	tags map[string]string,
) (*deployed, error) {
	policyJSON, err := readRepoFile("policy.json")
	if err != nil {
		return nil, err
	}
	trustRaw, err := readRepoFile("role.json")
	if err != nil {
		return nil, err
	}
	trustJSON := strings.ReplaceAll(trustRaw, "<ENT_AWS_ACCOUNT_ARN>", entAwsAccountArn)

	policy, err := iam.NewPolicy(ctx, "EntHomeAccess", &iam.PolicyArgs{
		Name:        pulumi.String(policyName),
		Description: pulumi.String(policyDescription),
		Path:        pulumi.String("/"),
		Policy:      pulumi.String(policyJSON),
	})
	if err != nil {
		return nil, err
	}

	pulumiTags := pulumi.StringMap{}
	for k, v := range tags {
		pulumiTags[k] = pulumi.String(v)
	}

	role, err := iam.NewRole(ctx, "EntDeployRole", &iam.RoleArgs{
		Name:             pulumi.String(roleName),
		Path:             pulumi.String(rolePath),
		Description:      pulumi.String(roleDescription),
		AssumeRolePolicy: pulumi.String(trustJSON),
		Tags:             pulumiTags,
	})
	if err != nil {
		return nil, err
	}

	_, err = iam.NewRolePolicyAttachment(ctx, "EntDeployRoleAttachment", &iam.RolePolicyAttachmentArgs{
		Role:      role.Name,
		PolicyArn: policy.Arn,
	})
	if err != nil {
		return nil, err
	}

	return &deployed{Policy: policy, Role: role}, nil
}

func main() {
	pulumi.Run(func(ctx *pulumi.Context) error {
		cfg := config.New(ctx, "ent-deploy-role")

		entAwsAccountArn := cfg.Get("entAwsAccountArn")
		if entAwsAccountArn == "" {
			entAwsAccountArn = defaultEntAwsAccountArn
		}
		roleName := cfg.Get("roleName")
		if roleName == "" {
			roleName = defaultRoleName
		}
		rolePath := cfg.Get("rolePath")
		if rolePath == "" {
			rolePath = defaultRolePath
		}
		roleDescription := cfg.Get("roleDescription")
		if roleDescription == "" {
			roleDescription = defaultRoleDescription
		}
		tags := map[string]string{}
		_ = cfg.TryObject("tags", &tags)

		result, err := deploy(ctx, entAwsAccountArn, roleName, rolePath, roleDescription, tags)
		if err != nil {
			return err
		}

		ctx.Export("roleArn", result.Role.Arn)
		ctx.Export("roleName", result.Role.Name)
		ctx.Export("policyArn", result.Policy.Arn)
		return nil
	})
}
