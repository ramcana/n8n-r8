import { SimpleExample } from '../../src/nodes/SimpleExample.node';

describe('SimpleExample Node', () => {
	let node: SimpleExample;

	beforeEach(() => {
		node = new SimpleExample();
	});

	describe('Node Description', () => {
		test('should have correct basic properties', () => {
			expect(node.description.displayName).toBe('Simple Example');
			expect(node.description.name).toBe('simpleExample');
			expect(node.description.group).toContain('transform');
			expect(node.description.version).toBe(1);
		});

		test('should have correct inputs and outputs', () => {
			expect(node.description.inputs).toEqual(['main']);
			expect(node.description.outputs).toEqual(['main']);
		});

		test('should have properties defined', () => {
			expect(node.description.properties).toBeDefined();
			expect(node.description.properties.length).toBeGreaterThan(0);
		});

		test('should have message parameter', () => {
			const messageParam = node.description.properties.find(p => p.name === 'message');
			expect(messageParam).toBeDefined();
			expect(messageParam?.type).toBe('string');
			expect(messageParam?.default).toBe('Hello from N8N-R8 Custom Node!');
		});

		test('should have addTimestamp parameter', () => {
			const timestampParam = node.description.properties.find(p => p.name === 'addTimestamp');
			expect(timestampParam).toBeDefined();
			expect(timestampParam?.type).toBe('boolean');
			expect(timestampParam?.default).toBe(true);
		});
	});
});
