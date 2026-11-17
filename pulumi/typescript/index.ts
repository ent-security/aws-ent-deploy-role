// Pulumi entrypoint. Every export here becomes a stack output, so re-export only the stack's outputs;
// the program and its test hooks live in infra.ts.
export { policies, role, roleArn, policyArns, policyArn } from './infra';
