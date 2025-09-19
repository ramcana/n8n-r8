// N8N-R8 Custom Nodes Entry Point
// This file exports all custom nodes and credentials

// Export all nodes
export * from './nodes/SimpleExample.node';
export * from './nodes/HttpTrigger.node';

// Export all credentials
export * from './credentials/SimpleApi.credentials';

// You can also export them individually for better tree-shaking
// export { SimpleExample } from './nodes/SimpleExample.node';
// export { HttpTrigger } from './nodes/HttpTrigger.node';
// export { SimpleApi } from './credentials/SimpleApi.credentials';

// Version information
export const version = '1.0.0';
export const description = 'N8N-R8 Custom Nodes Package';

// Node metadata for N8N discovery
export const nodes = [
	'./nodes/SimpleExample.node',
	'./nodes/HttpTrigger.node',
];

export const credentials = [
	'./credentials/SimpleApi.credentials',
];
