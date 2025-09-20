import {
	IDataObject,
	IHookFunctions,
	INodeType,
	INodeTypeDescription,
	IWebhookFunctions,
	IWebhookResponseData,
} from 'n8n-workflow';

export class HttpTrigger implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'HTTP Trigger',
		name: 'httpTrigger',
		icon: 'fa:satellite-dish',
		group: ['trigger'],
		version: 1,
		description: 'Starts the workflow when an HTTP request is received',
		defaults: {
			name: 'HTTP Trigger',
		},
		inputs: [],
		outputs: ['main'],
		webhooks: [
			{
				name: 'default',
				httpMethod: '={{$parameter["httpMethod"]}}',
				responseMode: 'onReceived',
				path: '={{$parameter["path"]}}',
			},
		],
		properties: [
			{
				displayName: 'HTTP Method',
				name: 'httpMethod',
				type: 'options',
				options: [
					{
						name: 'GET',
						value: 'GET',
					},
					{
						name: 'POST',
						value: 'POST',
					},
					{
						name: 'PUT',
						value: 'PUT',
					},
					{
						name: 'DELETE',
						value: 'DELETE',
					},
					{
						name: 'PATCH',
						value: 'PATCH',
					},
				],
				default: 'POST',
				description: 'The HTTP method to listen for',
			},
			{
				displayName: 'Path',
				name: 'path',
				type: 'string',
				default: '',
				placeholder: 'webhook-path',
				required: true,
				description: 'The path for the webhook URL',
			},
			{
				displayName: 'Response Mode',
				name: 'responseMode',
				type: 'options',
				options: [
					{
						name: 'On Received',
						value: 'onReceived',
						description: 'Returns response immediately when webhook is received',
					},
					{
						name: 'Last Node',
						value: 'lastNode',
						description: 'Returns response from the last executed node',
					},
				],
				default: 'onReceived',
				description: 'When to return the response',
			},
			{
				displayName: 'Response Code',
				name: 'responseCode',
				type: 'number',
				typeOptions: {
					minValue: 100,
					maxValue: 599,
				},
				default: 200,
				description: 'The HTTP response code to return',
			},
			{
				displayName: 'Response Data',
				name: 'responseData',
				type: 'string',
				displayOptions: {
					show: {
						responseMode: ['onReceived'],
					},
				},
				default: 'success',
				description: 'The response data to return',
			},
			{
				displayName: 'Options',
				name: 'options',
				type: 'collection',
				placeholder: 'Add Option',
				default: {},
				options: [
					{
						displayName: 'No Response Body',
						name: 'noResponseBody',
						type: 'boolean',
						default: false,
						description: 'Whether to send a response body or not',
					},
					{
						displayName: 'Raw Body',
						name: 'rawBody',
						type: 'boolean',
						default: false,
						description: 'Whether to return the raw body or parsed JSON',
					},
				],
			},
		],
	};

	webhookMethods = {
		default: {
			async checkExists(this: IHookFunctions): Promise<boolean> {
				const webhookUrl = this.getNodeWebhookUrl('default');
				const webhookData = this.getWorkflowStaticData('node');

				return webhookData.webhookId === webhookUrl;
			},
			async create(this: IHookFunctions): Promise<boolean> {
				const webhookUrl = this.getNodeWebhookUrl('default');
				const webhookData = this.getWorkflowStaticData('node');

				webhookData.webhookId = webhookUrl;

				return true;
			},
			async delete(this: IHookFunctions): Promise<boolean> {
				const webhookData = this.getWorkflowStaticData('node');

				delete webhookData.webhookId;

				return true;
			},
		},
	};

	async webhook(this: IWebhookFunctions): Promise<IWebhookResponseData> {
		const options = this.getNodeParameter('options', {}) as IDataObject;
		const responseMode = this.getNodeParameter('responseMode', 'onReceived') as string;
		const responseCode = this.getNodeParameter('responseCode', 200) as number;
		const responseData = this.getNodeParameter('responseData', 'success') as string;

		const req = this.getRequestObject();
		const resp = this.getResponseObject();
		const headers = this.getHeaderData();
		const queryData = this.getQueryData();

		let body: any = {};

		if (req.body) {
			if (options.rawBody === true) {
				body = req.body;
			} else {
				body = this.getBodyData();
			}
		}

		// Prepare the data to return
		const returnData = {
			headers,
			params: queryData,
			body,
			method: req.method,
			url: req.url,
			timestamp: new Date().toISOString(),
		};

		if (responseMode === 'onReceived') {
			if (options.noResponseBody === true) {
				resp.status(responseCode).end();
			} else {
				resp.status(responseCode).json({ message: responseData });
			}

			return {
				workflowData: [
					[
						{
							json: returnData,
						},
					],
				],
			};
		}

		// For 'lastNode' mode, return the data and let n8n handle the response
		return {
			workflowData: [
				[
					{
						json: returnData,
					},
				],
			],
		};
	}
}
