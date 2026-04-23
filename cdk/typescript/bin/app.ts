#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { EntDeployRoleStack } from '../lib/ent-deploy-role-stack';

const app = new cdk.App();

const tagsCtx = app.node.tryGetContext('tags');

new EntDeployRoleStack(app, 'EntDeployRoleStack', {
  entAwsAccountArn: app.node.tryGetContext('ent_aws_account_arn'),
  roleName: app.node.tryGetContext('role_name'),
  rolePath: app.node.tryGetContext('role_path'),
  roleDescription: app.node.tryGetContext('role_description'),
  entTags: tagsCtx && typeof tagsCtx === 'object' ? tagsCtx : undefined,
});
