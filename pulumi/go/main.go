package main

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws"
	"github.com/pulumi/pulumi-aws/sdk/v6/go/aws/iam"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi/config"
)

type deployed struct {
	Policies       []*iam.Policy
	Role           *iam.Role
	BoundaryPolicy *iam.Policy
}

const (
	defaultEntAwsAccountArn = "arn:aws:iam::000000000000:root"
	defaultRoleName         = "HomeProdAssumeAdmin"
	defaultRolePath         = "/"
	defaultRoleDescription  = "Role that allows Ent Home to assume AdministratorAccess role"
	policyNamePrefix        = "EntHomeAccess"
	policyDescription       = "Custom policy for permissions needed by Ent Home to deploy and manage resources in customer accounts. This policy is attached to the role that Ent Home assumes when deploying resources in customer accounts."
	// Suffix of the functional policy whose ARN backs the deprecated single-ARN policyArn export.
	compatPolicySuffix = "Security"
)

// policyFile pairs an authoritative functional policy file with the suffix appended to
// policyNamePrefix to name its managed policy.
type policyFile struct {
	Filename string
	Suffix   string
}

// The permission set is split across four functional managed policies so each stays under AWS's
// 6144-character managed-policy limit. The policies are named policyNamePrefix+Suffix (default
// EntHomeAccess{Compute,Data,Security,Platform}). The union of the four is the complete permission
// set. Keep this in lockstep with the Terraform statement_group map and the files.
var policyFiles = []policyFile{
	{"EntHomeAccess.compute-network.json", "Compute"},
	{"EntHomeAccess.data-storage.json", "Data"},
	{"EntHomeAccess.identity-security.json", "Security"},
	{"EntHomeAccess.observability-platform.json", "Platform"},
}

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
	// The functional policy files hold the canonical (commercial) `arn:aws:` ARNs. Rewrite the
	// partition to the one we're deploying into so the policies work in commercial and GovCloud
	// (aws-us-gov) alike. Each file becomes its own managed policy, mirroring the Terraform module.
	part, err := aws.GetPartition(ctx, nil)
	if err != nil {
		return nil, err
	}

	policies := make([]*iam.Policy, 0, len(policyFiles))
	for _, pf := range policyFiles {
		policyJSON, err := readRepoFile(pf.Filename)
		if err != nil {
			return nil, err
		}
		policyJSON = strings.ReplaceAll(policyJSON, "arn:aws:", "arn:"+part.Partition+":")
		policy, err := iam.NewPolicy(ctx, "EntHomeAccess"+pf.Suffix, &iam.PolicyArgs{
			Name:        pulumi.String(policyNamePrefix + pf.Suffix),
			Description: pulumi.String(policyDescription),
			Path:        pulumi.String("/"),
			Policy:      pulumi.String(policyJSON),
		})
		if err != nil {
			return nil, err
		}
		policies = append(policies, policy)
	}

	// Permissions boundary for IAMBoundaryEnforcement (in EntHomeAccess.identity-security.json). NOT
	// attached to the deploy role itself below -- it would strip the deploy role's own
	// iam:*/sts:AssumeRole grants on the glob, breaking it. It exists only to be referenced by ARN
	// when the deploy role creates a new role under role/e???????????????-*, capping that new
	// role's effective permissions regardless of what policy gets attached to it. No partition
	// rewrite needed: its Action/Resource entries carry no ARNs.
	boundaryJSON, err := readRepoFile("EntHomeAccess.boundary.json")
	if err != nil {
		return nil, err
	}
	boundaryPolicy, err := iam.NewPolicy(ctx, "EntHomeAccessBoundary", &iam.PolicyArgs{
		Name:        pulumi.String(policyNamePrefix + "Boundary"),
		Description: pulumi.String("Permissions boundary for IAM roles created by the deploy role under role/e???????????????-*. Not attached to the deploy role itself."),
		Path:        pulumi.String("/"),
		Policy:      pulumi.String(boundaryJSON),
	})
	if err != nil {
		return nil, err
	}

	trustRaw, err := readRepoFile("role.json")
	if err != nil {
		return nil, err
	}
	trustJSON := strings.ReplaceAll(trustRaw, "<ENT_AWS_ACCOUNT_ARN>", entAwsAccountArn)

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

	// One attachment per functional policy.
	for i, policy := range policies {
		_, err = iam.NewRolePolicyAttachment(ctx, "EntDeployRoleAttachment"+policyFiles[i].Suffix, &iam.RolePolicyAttachmentArgs{
			Role:      role.Name,
			PolicyArn: policy.Arn,
		})
		if err != nil {
			return nil, err
		}
	}

	return &deployed{Policies: policies, Role: role, BoundaryPolicy: boundaryPolicy}, nil
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

		policyArns := make(pulumi.StringArray, 0, len(result.Policies))
		for _, p := range result.Policies {
			policyArns = append(policyArns, p.Arn)
		}
		ctx.Export("policyArns", policyArns.ToStringArrayOutput())

		// Backward-compat single ARN: EntHomeAccessSecurity. Deprecated -- use policyArns.
		for i, pf := range policyFiles {
			if pf.Suffix == compatPolicySuffix {
				ctx.Export("policyArn", result.Policies[i].Arn)
			}
		}
		ctx.Export("boundaryPolicyArn", result.BoundaryPolicy.Arn)
		return nil
	})
}
