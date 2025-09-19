import {
	IExecuteFunctions,
	INodeExecutionData,
	INodeType,
	INodeTypeDescription,
	NodeOperationError,
} from 'n8n-workflow';

export class ExampleNode implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Example Node',
		name: 'exampleNode',
		icon: 'file:example.svg',
		group: ['transform'],
		version: 1,
		subtitle: '={{$parameter["operation"] + ": " + $parameter["resource"]}}',
		description: 'Example custom node for N8N-R8',
		defaults: {
			name: 'Example Node',
		},
		inputs: ['main'],
		outputs: ['main'],
		credentials: [
			{
				name: 'exampleApi',
				required: false,
			},
		],
		requestDefaults: {
			baseURL: 'https://api.example.com',
			headers: {
				Accept: 'application/json',
				'Content-Type': 'application/json',
			},
		},
		properties: [
			{
				displayName: 'Resource',
				name: 'resource',
				type: 'options',
				noDataExpression: true,
				options: [
					{
						name: 'User',
						value: 'user',
					},
					{
						name: 'Post',
						value: 'post',
					},
				],
				default: 'user',
			},
			{
				displayName: 'Operation',
				name: 'operation',
				type: 'options',
				noDataExpression: true,
				displayOptions: {
					show: {
						resource: ['user'],
					},
				},
				options: [
					{
						name: 'Create',
						value: 'create',
						description: 'Create a new user',
						action: 'Create a user',
					},
					{
						name: 'Get',
						value: 'get',
						description: 'Get a user',
						action: 'Get a user',
					},
					{
						name: 'Get Many',
						value: 'getAll',
						description: 'Get many users',
						action: 'Get many users',
					},
					{
						name: 'Update',
						value: 'update',
						description: 'Update a user',
						action: 'Update a user',
					},
					{
						name: 'Delete',
						value: 'delete',
						description: 'Delete a user',
						action: 'Delete a user',
					},
				],
				default: 'get',
			},
			{
				displayName: 'Operation',
				name: 'operation',
				type: 'options',
				noDataExpression: true,
				displayOptions: {
					show: {
						resource: ['post'],
					},
				},
				options: [
					{
						name: 'Create',
						value: 'create',
						description: 'Create a new post',
						action: 'Create a post',
					},
					{
						name: 'Get',
						value: 'get',
						description: 'Get a post',
						action: 'Get a post',
					},
					{
						name: 'Get Many',
						value: 'getAll',
						description: 'Get many posts',
						action: 'Get many posts',
					},
				],
				default: 'get',
			},
			// User operations parameters
			{
				displayName: 'User ID',
				name: 'userId',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['user'],
						operation: ['get', 'update', 'delete'],
					},
				},
				default: '',
				placeholder: '12345',
				description: 'The ID of the user',
			},
			{
				displayName: 'User Name',
				name: 'userName',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['user'],
						operation: ['create', 'update'],
					},
				},
				default: '',
				placeholder: 'John Doe',
				description: 'The name of the user',
			},
			{
				displayName: 'Email',
				name: 'email',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['user'],
						operation: ['create', 'update'],
					},
				},
				default: '',
				placeholder: 'john@example.com',
				description: 'The email address of the user',
			},
			{
				displayName: 'Return All',
				name: 'returnAll',
				type: 'boolean',
				displayOptions: {
					show: {
						resource: ['user'],
						operation: ['getAll'],
					},
				},
				default: false,
				description: 'Whether to return all results or only up to a given limit',
			},
			{
				displayName: 'Limit',
				name: 'limit',
				type: 'number',
				displayOptions: {
					show: {
						resource: ['user'],
						operation: ['getAll'],
						returnAll: [false],
					},
				},
				typeOptions: {
					minValue: 1,
					maxValue: 100,
				},
				default: 50,
				description: 'Max number of results to return',
			},
			// Post operations parameters
			{
				displayName: 'Post ID',
				name: 'postId',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['post'],
						operation: ['get'],
					},
				},
				default: '',
				placeholder: '67890',
				description: 'The ID of the post',
			},
			{
				displayName: 'Title',
				name: 'title',
				type: 'string',
				required: true,
				displayOptions: {
					show: {
						resource: ['post'],
						operation: ['create'],
					},
				},
				default: '',
				placeholder: 'My Post Title',
				description: 'The title of the post',
			},
			{
				displayName: 'Content',
				name: 'content',
				type: 'string',
				typeOptions: {
					rows: 4,
				},
				required: true,
				displayOptions: {
					show: {
						resource: ['post'],
						operation: ['create'],
					},
				},
				default: '',
				placeholder: 'Post content goes here...',
				description: 'The content of the post',
			},
			{
				displayName: 'Additional Fields',
				name: 'additionalFields',
				type: 'collection',
				placeholder: 'Add Field',
				default: {},
				displayOptions: {
					show: {
						resource: ['user', 'post'],
						operation: ['create', 'update'],
					},
				},
				options: [
					{
						displayName: 'Tags',
						name: 'tags',
						type: 'string',
						default: '',
						placeholder: 'tag1, tag2, tag3',
						description: 'Comma-separated list of tags',
					},
					{
						displayName: 'Status',
						name: 'status',
						type: 'options',
						options: [
							{
								name: 'Active',
								value: 'active',
							},
							{
								name: 'Inactive',
								value: 'inactive',
							},
							{
								name: 'Pending',
								value: 'pending',
							},
						],
						default: 'active',
						description: 'The status of the item',
					},
				],
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const returnData: INodeExecutionData[] = [];

		const resource = this.getNodeParameter('resource', 0) as string;
		const operation = this.getNodeParameter('operation', 0) as string;

		for (let i = 0; i < items.length; i++) {
			try {
				let responseData: any = {};

				if (resource === 'user') {
					responseData = await this.handleUserOperations(operation, i);
				} else if (resource === 'post') {
					responseData = await this.handlePostOperations(operation, i);
				}

				const executionData = this.helpers.constructExecutionMetaData(
					this.helpers.returnJsonArray(responseData),
					{ itemData: { item: i } },
				);

				returnData.push(...executionData);
			} catch (error) {
				if (this.continueOnFail()) {
					const executionErrorData = this.helpers.constructExecutionMetaData(
						this.helpers.returnJsonArray({ error: error.message }),
						{ itemData: { item: i } },
					);
					returnData.push(...executionErrorData);
					continue;
				}
				throw error;
			}
		}

		return [returnData];
	}

	private async handleUserOperations(operation: string, itemIndex: number): Promise<any> {
		switch (operation) {
			case 'create':
				return this.createUser(itemIndex);
			case 'get':
				return this.getUser(itemIndex);
			case 'getAll':
				return this.getAllUsers(itemIndex);
			case 'update':
				return this.updateUser(itemIndex);
			case 'delete':
				return this.deleteUser(itemIndex);
			default:
				throw new NodeOperationError(
					this.getNode(),
					`The operation "${operation}" is not supported for resource "user"!`,
					{ itemIndex },
				);
		}
	}

	private async handlePostOperations(operation: string, itemIndex: number): Promise<any> {
		switch (operation) {
			case 'create':
				return this.createPost(itemIndex);
			case 'get':
				return this.getPost(itemIndex);
			case 'getAll':
				return this.getAllPosts(itemIndex);
			default:
				throw new NodeOperationError(
					this.getNode(),
					`The operation "${operation}" is not supported for resource "post"!`,
					{ itemIndex },
				);
		}
	}

	private async createUser(itemIndex: number): Promise<any> {
		const userName = this.getNodeParameter('userName', itemIndex) as string;
		const email = this.getNodeParameter('email', itemIndex) as string;
		const additionalFields = this.getNodeParameter('additionalFields', itemIndex) as any;

		const body: any = {
			name: userName,
			email,
			...additionalFields,
		};

		// Simulate API call
		const responseData = {
			id: Math.floor(Math.random() * 10000),
			...body,
			created_at: new Date().toISOString(),
			updated_at: new Date().toISOString(),
		};

		return responseData;
	}

	private async getUser(itemIndex: number): Promise<any> {
		const userId = this.getNodeParameter('userId', itemIndex) as string;

		// Simulate API call
		const responseData = {
			id: parseInt(userId, 10),
			name: 'John Doe',
			email: 'john@example.com',
			status: 'active',
			created_at: '2023-01-01T00:00:00Z',
			updated_at: '2023-01-01T00:00:00Z',
		};

		return responseData;
	}

	private async getAllUsers(itemIndex: number): Promise<any> {
		const returnAll = this.getNodeParameter('returnAll', itemIndex) as boolean;
		const limit = this.getNodeParameter('limit', itemIndex, 50) as number;

		// Simulate API call
		const users = [];
		const totalUsers = returnAll ? 100 : Math.min(limit, 100);

		for (let i = 1; i <= totalUsers; i++) {
			users.push({
				id: i,
				name: `User ${i}`,
				email: `user${i}@example.com`,
				status: i % 2 === 0 ? 'active' : 'inactive',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z',
			});
		}

		return users;
	}

	private async updateUser(itemIndex: number): Promise<any> {
		const userId = this.getNodeParameter('userId', itemIndex) as string;
		const userName = this.getNodeParameter('userName', itemIndex) as string;
		const email = this.getNodeParameter('email', itemIndex) as string;
		const additionalFields = this.getNodeParameter('additionalFields', itemIndex) as any;

		const body: any = {
			name: userName,
			email,
			...additionalFields,
		};

		// Simulate API call
		const responseData = {
			id: parseInt(userId, 10),
			...body,
			updated_at: new Date().toISOString(),
		};

		return responseData;
	}

	private async deleteUser(itemIndex: number): Promise<any> {
		const userId = this.getNodeParameter('userId', itemIndex) as string;

		// Simulate API call
		const responseData = {
			id: parseInt(userId, 10),
			deleted: true,
			deleted_at: new Date().toISOString(),
		};

		return responseData;
	}

	private async createPost(itemIndex: number): Promise<any> {
		const title = this.getNodeParameter('title', itemIndex) as string;
		const content = this.getNodeParameter('content', itemIndex) as string;
		const additionalFields = this.getNodeParameter('additionalFields', itemIndex) as any;

		const body: any = {
			title,
			content,
			...additionalFields,
		};

		// Simulate API call
		const responseData = {
			id: Math.floor(Math.random() * 10000),
			...body,
			author_id: 1,
			created_at: new Date().toISOString(),
			updated_at: new Date().toISOString(),
		};

		return responseData;
	}

	private async getPost(itemIndex: number): Promise<any> {
		const postId = this.getNodeParameter('postId', itemIndex) as string;

		// Simulate API call
		const responseData = {
			id: parseInt(postId, 10),
			title: 'Sample Post',
			content: 'This is a sample post content.',
			author_id: 1,
			status: 'published',
			created_at: '2023-01-01T00:00:00Z',
			updated_at: '2023-01-01T00:00:00Z',
		};

		return responseData;
	}

	private async getAllPosts(itemIndex: number): Promise<any> {
		// Simulate API call
		const posts = [];

		for (let i = 1; i <= 10; i++) {
			posts.push({
				id: i,
				title: `Post ${i}`,
				content: `Content for post ${i}`,
				author_id: 1,
				status: 'published',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z',
			});
		}

		return posts;
	}
}
