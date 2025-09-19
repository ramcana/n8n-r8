import {
	ICredentialType,
	INodeProperties,
} from 'n8n-workflow';

export class SimpleApi implements ICredentialType {
	name = 'simpleApi';
	displayName = 'Simple API';
	documentationUrl = 'https://docs.n8n.io/credentials/';
	properties: INodeProperties[] = [
		{
			displayName: 'API Key',
			name: 'apiKey',
			type: 'string',
			typeOptions: {
				password: true,
			},
			default: '',
			description: 'The API key for authentication',
		},
		{
			displayName: 'Base URL',
			name: 'baseUrl',
			type: 'string',
			default: 'https://api.example.com',
			description: 'The base URL of the API',
		},
	];
}
