import { HttpTrigger } from '../../src/nodes/HttpTrigger.node';

describe('HttpTrigger Node', () => {
	let node: HttpTrigger;

	beforeEach(() => {
		node = new HttpTrigger();
	});

	describe('Node Description', () => {
		test('should have correct basic properties', () => {
			expect(node.description.displayName).toBe('HTTP Trigger');
			expect(node.description.name).toBe('httpTrigger');
			expect(node.description.group).toContain('trigger');
			expect(node.description.version).toBe(1);
		});

		test('should have correct inputs and outputs', () => {
			expect(node.description.inputs).toEqual([]);
			expect(node.description.outputs).toEqual(['main']);
		});

		test('should have webhooks defined', () => {
			expect(node.description.webhooks).toBeDefined();
			expect(node.description.webhooks).toHaveLength(1);
			expect(node.description.webhooks![0].name).toBe('default');
		});

		test('should have HTTP method parameter', () => {
			const methodParam = node.description.properties.find(p => p.name === 'httpMethod');
			expect(methodParam).toBeDefined();
			expect(methodParam?.type).toBe('options');
			expect(methodParam?.default).toBe('POST');
		});

		test('should have path parameter', () => {
			const pathParam = node.description.properties.find(p => p.name === 'path');
			expect(pathParam).toBeDefined();
			expect(pathParam?.type).toBe('string');
			expect(pathParam?.required).toBe(true);
		});

		test('should have response mode parameter', () => {
			const responseModeParam = node.description.properties.find(p => p.name === 'responseMode');
			expect(responseModeParam).toBeDefined();
			expect(responseModeParam?.type).toBe('options');
			expect(responseModeParam?.default).toBe('onReceived');
		});

		test('should have response code parameter', () => {
			const responseCodeParam = node.description.properties.find(p => p.name === 'responseCode');
			expect(responseCodeParam).toBeDefined();
			expect(responseCodeParam?.type).toBe('number');
			expect(responseCodeParam?.default).toBe(200);
		});
	});

	describe('HTTP Methods', () => {
		test('should support all HTTP methods', () => {
			const methodParam = node.description.properties.find(p => p.name === 'httpMethod');
			const options = methodParam?.options as Array<{name: string, value: string}>;
			
			expect(options).toBeDefined();
			expect(options.map(o => o.value)).toEqual(['GET', 'POST', 'PUT', 'DELETE', 'PATCH']);
		});
	});

	describe('Webhook Methods', () => {
		test('should have webhook methods defined', () => {
			expect(node.webhookMethods).toBeDefined();
			expect(node.webhookMethods.default).toBeDefined();
			expect(node.webhookMethods.default.checkExists).toBeDefined();
			expect(node.webhookMethods.default.create).toBeDefined();
			expect(node.webhookMethods.default.delete).toBeDefined();
		});
	});
});
