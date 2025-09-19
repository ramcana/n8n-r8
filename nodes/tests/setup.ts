// Jest setup file for N8N custom nodes testing

import { jest } from '@jest/globals';

// Mock N8N workflow functions
global.jest = jest;

// Mock console methods in tests
const originalConsole = console;

beforeEach(() => {
	// Reset console mocks before each test
	jest.clearAllMocks();
});

afterEach(() => {
	// Restore console after each test
	global.console = originalConsole;
});

// Mock N8N execution context
export const mockExecuteFunctions = {
	getInputData: jest.fn(),
	getNodeParameter: jest.fn(),
	getCredentials: jest.fn(),
	continueOnFail: jest.fn().mockReturnValue(false),
	getNode: jest.fn().mockReturnValue({
		name: 'Test Node',
		type: 'test-node',
		typeVersion: 1,
	}),
	helpers: {
		request: jest.fn(),
		requestWithAuthentication: jest.fn(),
		returnJsonArray: jest.fn((data) => (Array.isArray(data) ? data : [data])),
		constructExecutionMetaData: jest.fn((data: any[], metadata?: any) => 
			(Array.isArray(data) ? data : [data]).map((item: any) => ({
				json: item,
				pairedItem: metadata?.itemData?.item !== undefined ? { item: metadata.itemData.item } : undefined,
			}))
		),
	},
	logger: {
		debug: jest.fn(),
		info: jest.fn(),
		warn: jest.fn(),
		error: jest.fn(),
	},
};

// Mock credentials
export const mockCredentials = {
	apiKey: 'test-api-key',
	baseUrl: 'https://api.test.com',
	username: 'testuser',
	password: 'testpass',
};

// Helper function to reset all mocks
export const resetAllMocks = () => {
	Object.values(mockExecuteFunctions).forEach((mock) => {
		if (typeof mock === 'object' && mock !== null) {
			Object.values(mock).forEach((nestedMock) => {
				if (jest.isMockFunction(nestedMock)) {
					nestedMock.mockReset();
				}
			});
		} else if (jest.isMockFunction(mock)) {
			mock.mockReset();
		}
	});
};

// Helper function to setup common mocks
export const setupCommonMocks = (inputData = [{ json: { test: 'data' } }]) => {
	mockExecuteFunctions.getInputData.mockReturnValue(inputData);
	mockExecuteFunctions.getCredentials.mockResolvedValue(mockCredentials as any);
	mockExecuteFunctions.continueOnFail.mockReturnValue(false);
	
	return mockExecuteFunctions;
};

// Mock HTTP responses
export const mockHttpResponse = {
	success: {
		status: 200,
		data: { success: true, message: 'Operation completed' },
	},
	error: {
		status: 400,
		data: { error: true, message: 'Bad request' },
	},
	notFound: {
		status: 404,
		data: { error: true, message: 'Not found' },
	},
};

// Test data generators
export const generateTestUser = (id = 1) => ({
	id,
	name: `Test User ${id}`,
	email: `user${id}@test.com`,
	status: 'active',
	created_at: '2023-01-01T00:00:00Z',
	updated_at: '2023-01-01T00:00:00Z',
});

export const generateTestPost = (id = 1) => ({
	id,
	title: `Test Post ${id}`,
	content: `Content for test post ${id}`,
	author_id: 1,
	status: 'published',
	created_at: '2023-01-01T00:00:00Z',
	updated_at: '2023-01-01T00:00:00Z',
});

// Utility functions for testing
export const expectNodeError = (error: any, expectedMessage?: string) => {
	expect(error).toBeDefined();
	if (expectedMessage) {
		expect(error.message).toContain(expectedMessage);
	}
};

export const expectValidNodeOutput = (output: any) => {
	expect(output).toBeDefined();
	expect(Array.isArray(output)).toBe(true);
	expect(output.length).toBeGreaterThan(0);
	expect(Array.isArray(output[0])).toBe(true);
};
