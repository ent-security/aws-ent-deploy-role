#!/usr/bin/env python3
"""Fail if either CloudFormation template's EntDeployPolicyBoundaryGuard drifts from
EntHomeAccess.boundary-guard.json (the source Terraform, CDK and Pulumi render)."""
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
ARN = "arn:aws:iam::123456789012:policy/Boundary"


class Loader(yaml.SafeLoader):
    pass


def construct_tag(loader, suffix, node):
    if isinstance(node, yaml.ScalarNode):
        value = loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        value = loader.construct_sequence(node, deep=True)
    else:
        value = loader.construct_mapping(node, deep=True)
    return {"!" + suffix: value}


Loader.add_multi_constructor("!", construct_tag)


def resolve(v):
    # Only the intrinsics the guard uses: !Sub with ${AWS::Partition}, and !Ref PermissionsBoundaryArn.
    if isinstance(v, dict) and "!Sub" in v:
        return v["!Sub"].replace("${AWS::Partition}", "aws")
    if isinstance(v, dict) and v.get("!Ref") == "PermissionsBoundaryArn":
        return ARN
    if isinstance(v, dict):
        return {k: resolve(x) for k, x in v.items()}
    if isinstance(v, list):
        return [resolve(x) for x in v]
    return v


want = json.loads((ROOT / "EntHomeAccess.boundary-guard.json").read_text().replace("<PERMISSIONS_BOUNDARY_ARN>", ARN))
failed = False
for name in ("template.yaml", "template-autocomplete.yaml"):
    template = yaml.load((ROOT / "cloudformation" / name).read_text(), Loader=Loader)
    got = resolve(template["Resources"]["EntDeployPolicyBoundaryGuard"]["Properties"]["PolicyDocument"])
    if got != want:
        print(f"cloudformation/{name}: EntDeployPolicyBoundaryGuard drifted from EntHomeAccess.boundary-guard.json")
        failed = True
    else:
        print(f"cloudformation/{name}: guard matches EntHomeAccess.boundary-guard.json")
sys.exit(1 if failed else 0)
