import { ExampleNode } from '../../src/nodes/ExampleNode.node';
import {
	mockExecuteFunctions,
	setupCommonMocks,
	resetAllMocks,
	generateTestUser,
	generateTestPost,
	expectValidNodeOutput,
	expectNodeError,
} from '../setup';

describe('ExampleNode', () => {
	let node: ExampleNode;

	beforeEach(() => {
		node = new ExampleNode();
		resetAllMocks();
	});

	describe('Node Description', () => {
		test('should have correct basic properties', () => {
			expect(node.description.displayName).toBe('Example Node');
			expect(node.description.name).toBe('exampleNode');
			expect(node.description.group).toContain('transform');
			expect(node.description.version).toBe(1);
		});

		test('should have correct inputs and outputs', () => {
			expect(node.description.inputs).toEqual(['main']);
			expect(node.description.outputs).toEqual(['main']);
		});

		test('should have credentials defined', () => {
			expect(node.description.credentials).toBeDefined();
			expect(node.description.credentials).toHaveLength(1);
			expect(node.description.credentials![0].name).toBe('exampleApi');
		});

		test('should have properties defined', () => {
			expect(node.description.properties).toBeDefined();
			expect(node.description.properties.length).toBeGreaterThan(0);
		});
	});

	describe('User Operations', () => {
		beforeEach(() => {
			setupCommonMocks();
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('get'); // operation
		});

		test('should get a user', async () => {
			const userId = '123';
			mockExecuteFunctions.getNodeParameter.mockReturnValueOnce(userId);

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.id).toBe(parseInt(userId, 10));
			expect(result[0][0].json.name).toBe('John Doe');
		});

		test('should create a user', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('create') // operation
				.mockReturnValueOnce('John Doe') // userName
				.mockReturnValueOnce('john@example.com') // email
				.mockReturnValueOnce({}); // additionalFields

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.name).toBe('John Doe');
			expect(result[0][0].json.email).toBe('john@example.com');
			expect(result[0][0].json.id).toBeDefined();
		});

		test('should get all users', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('getAll') // operation
				.mockReturnValueOnce(false) // returnAll
				.mockReturnValueOnce(5); // limit

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(5);
			result[0].forEach((item, index) => {
				expect(item.json.id).toBe(index + 1);
				expect(item.json.name).toBe(`User ${index + 1}`);
			});
		});

		test('should update a user', async () => {
			const userId = '123';
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('update') // operation
				.mockReturnValueOnce(userId) // userId
				.mockReturnValueOnce('Jane Doe') // userName
				.mockReturnValueOnce('jane@example.com') // email
				.mockReturnValueOnce({ status: 'inactive' }); // additionalFields

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.id).toBe(parseInt(userId, 10));
			expect(result[0][0].json.name).toBe('Jane Doe');
			expect(result[0][0].json.email).toBe('jane@example.com');
			expect(result[0][0].json.status).toBe('inactive');
		});

		test('should delete a user', async () => {
			const userId = '123';
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('delete') // operation
				.mockReturnValueOnce(userId); // userId

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.id).toBe(parseInt(userId, 10));
			expect(result[0][0].json.deleted).toBe(true);
			expect(result[0][0].json.deleted_at).toBeDefined();
		});
	});

	describe('Post Operations', () => {
		beforeEach(() => {
			setupCommonMocks();
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('post') // resource
				.mockReturnValueOnce('get'); // operation
		});

		test('should get a post', async () => {
			const postId = '456';
			mockExecuteFunctions.getNodeParameter.mockReturnValueOnce(postId);

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.id).toBe(parseInt(postId, 10));
			expect(result[0][0].json.title).toBe('Sample Post');
		});

		test('should create a post', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('post') // resource
				.mockReturnValueOnce('create') // operation
				.mockReturnValueOnce('My New Post') // title
				.mockReturnValueOnce('This is the content') // content
				.mockReturnValueOnce({ tags: 'test, example' }); // additionalFields

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.title).toBe('My New Post');
			expect(result[0][0].json.content).toBe('This is the content');
			expect(result[0][0].json.tags).toBe('test, example');
		});

		test('should get all posts', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('post') // resource
				.mockReturnValueOnce('getAll'); // operation

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(10);
			result[0].forEach((item, index) => {
				expect(item.json.id).toBe(index + 1);
				expect(item.json.title).toBe(`Post ${index + 1}`);
			});
		});
	});

	describe('Error Handling', () => {
		beforeEach(() => {
			setupCommonMocks();
		});

		test('should handle unsupported user operation', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('unsupported'); // operation

			await expect(node.execute.call(mockExecuteFunctions)).rejects.toThrow();
		});

		test('should handle unsupported post operation', async () => {
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('post') // resource
				.mockReturnValueOnce('unsupported'); // operation

			await expect(node.execute.call(mockExecuteFunctions)).rejects.toThrow();
		});

		test('should continue on fail when enabled', async () => {
			mockExecuteFunctions.continueOnFail.mockReturnValue(true);
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('user') // resource
				.mockReturnValueOnce('unsupported'); // operation

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(1);
			expect(result[0][0].json.error).toBeDefined();
		});
	});

	describe('Multiple Items Processing', () => {
		test('should process multiple items', async () => {
			const inputData = [
				{ json: { test: 'data1' } },
				{ json: { test: 'data2' } },
				{ json: { test: 'data3' } },
			];
			setupCommonMocks(inputData);

			// Mock parameters for each item
			mockExecuteFunctions.getNodeParameter
				.mockReturnValue('user') // resource for all items
				.mockReturnValue('get'); // operation for all items

			// Mock userId for each item
			mockExecuteFunctions.getNodeParameter
				.mockReturnValueOnce('1') // userId for item 0
				.mockReturnValueOnce('2') // userId for item 1
				.mockReturnValueOnce('3'); // userId for item 2

			const result = await node.execute.call(mockExecuteFunctions);

			expectValidNodeOutput(result);
			expect(result[0]).toHaveLength(3);
			
			result[0].forEach((item, index) => {
				expect(item.json.id).toBe(index + 1);
				expect(item.pairedItem?.item).toBe(index);
			});
		});
	});
});
