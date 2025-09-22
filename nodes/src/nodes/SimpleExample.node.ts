import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
} from 'n8n-workflow';

export class SimpleExample implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Simple Example',
		name: 'simpleExample',
		group: ['transform'],
		version: 1,
		description: 'A simple example node for N8N-R8',
		defaults: {
			name: 'Simple Example',
		},
		inputs: ['main'],
		outputs: ['main'],
		properties: [
			{
				displayName: 'Message',
				name: 'message',
				type: 'string',
				default: 'Hello from N8N-R8 Custom Node!',
				placeholder: 'Enter your message',
				description: 'The message to include in the output',
			},
			{
				displayName: 'Add Timestamp',
				name: 'addTimestamp',
				type: 'boolean',
				default: true,
				description: 'Whether to add a timestamp to the output',
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const returnData: INodeExecutionData[] = [];

		for (let i = 0; i < items.length; i++) {
			const message = this.getNodeParameter('message', i) as string;
			const addTimestamp = this.getNodeParameter('addTimestamp', i) as boolean;

			const outputData: IDataObject = {
				message,
				originalData: items[i].json,
			};

			if (addTimestamp) {
				outputData.timestamp = new Date().toISOString();
			}

			returnData.push({
				json: outputData,
			});
		}

		return [returnData];
	}
}
