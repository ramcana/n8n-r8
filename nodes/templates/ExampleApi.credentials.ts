import {
	IAuthenticateGeneric,
	ICredentialTestRequest,
	ICredentialType,
	INodeProperties,
} from 'n8n-workflow';

export class ExampleApi implements ICredentialType {
	name = 'exampleApi';

	displayName = 'Example API';

	documentationUrl = 'https://docs.example.com/api';

	properties: INodeProperties[] = [
		{
			displayName: 'Authentication Method',
			name: 'authType',
			type: 'options',
			options: [
				{
					name: 'API Key',
					value: 'apiKey',
				},
				{
					name: 'Bearer Token',
					value: 'bearerToken',
				},
				{
					name: 'Basic Auth',
					value: 'basicAuth',
				},
			],
			default: 'apiKey',
		},
		// API Key Authentication
		{
			displayName: 'API Key',
			name: 'apiKey',
			type: 'string',
			typeOptions: { password: true },
			displayOptions: {
				show: {
					authType: ['apiKey'],
				},
			},
			default: '',
			placeholder: 'your-api-key-here',
			description: 'The API key for authentication',
		},
		{
			displayName: 'API Key Header Name',
			name: 'apiKeyHeaderName',
			type: 'string',
			displayOptions: {
				show: {
					authType: ['apiKey'],
				},
			},
			default: 'X-API-Key',
			description: 'The header name for the API key',
		},
		// Bearer Token Authentication
		{
			displayName: 'Bearer Token',
			name: 'bearerToken',
			type: 'string',
			typeOptions: { password: true },
			displayOptions: {
				show: {
					authType: ['bearerToken'],
				},
			},
			default: '',
			placeholder: 'your-bearer-token-here',
			description: 'The bearer token for authentication',
		},
		// Basic Auth
		{
			displayName: 'Username',
			name: 'username',
			type: 'string',
			displayOptions: {
				show: {
					authType: ['basicAuth'],
				},
			},
			default: '',
			placeholder: 'username',
			description: 'The username for basic authentication',
		},
		{
			displayName: 'Password',
			name: 'password',
			type: 'string',
			typeOptions: { password: true },
			displayOptions: {
				show: {
					authType: ['basicAuth'],
				},
			},
			default: '',
			placeholder: 'password',
			description: 'The password for basic authentication',
		},
		// Common settings
		{
			displayName: 'Base URL',
			name: 'baseUrl',
			type: 'string',
			default: 'https://api.example.com',
			placeholder: 'https://api.example.com',
			description: 'The base URL of the API',
		},
		{
			displayName: 'API Version',
			name: 'apiVersion',
			type: 'options',
			options: [
				{
					name: 'v1',
					value: 'v1',
				},
				{
					name: 'v2',
					value: 'v2',
				},
			],
			default: 'v1',
			description: 'The API version to use',
		},
		{
			displayName: 'Timeout',
			name: 'timeout',
			type: 'number',
			default: 30000,
			description: 'Request timeout in milliseconds',
		},
		{
			displayName: 'Ignore SSL Issues',
			name: 'ignoreSSLIssues',
			type: 'boolean',
			default: false,
			description: 'Whether to ignore SSL certificate issues',
		},
	];

	// Define how to authenticate requests
	authenticate: IAuthenticateGeneric = {
		type: 'generic',
		properties: {
			headers: {
				'User-Agent': 'n8n-r8-custom-nodes/1.0.0',
			},
		},
	};

	// Test the credentials
	test: ICredentialTestRequest = {
		request: {
			baseURL: '={{$credentials.baseUrl}}/{{$credentials.apiVersion}}',
			url: '/auth/test',
			method: 'GET',
		},
		rules: [
			{
				type: 'responseSuccessBody',
				properties: {
					key: 'authenticated',
					value: true,
				},
			},
		],
	};
}
