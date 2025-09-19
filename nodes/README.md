# N8N-R8 Custom Nodes Development

This directory contains the development environment for creating custom N8N nodes for the N8N-R8 project.

## 🚀 Quick Start

### 1. Setup Development Environment

```bash
# Navigate to nodes directory
cd nodes/

# Install dependencies
npm install

# Or use the build script
./scripts/build.sh install
```

### 2. Create Your First Custom Node

```bash
# Copy the example template
cp templates/ExampleNode.node.ts src/nodes/MyCustomNode.node.ts
cp templates/ExampleApi.credentials.ts src/credentials/MyCustomApi.credentials.ts

# Edit your node
nano src/nodes/MyCustomNode.node.ts
```

### 2.1. Available Sample Nodes

The project includes several sample nodes to get you started:

- **SimpleExample Node**: Basic transformation node with message and timestamp functionality
- **HTTP Trigger Node**: Webhook trigger node for receiving HTTP requests
  - Supports GET, POST, PUT, DELETE, PATCH methods
  - Configurable response modes and status codes
  - Built-in request parsing and response handling

### 3. Build and Test

```bash
# Build the nodes
npm run build

# Or use the build script
./scripts/build.sh build

# Run tests
npm test

# Validate everything
./scripts/build.sh validate
```

### 4. Mount in N8N Container

```bash
# Build the nodes first
./scripts/build.sh build

# Start N8N with custom nodes mounted
cd ..
docker compose up -d
```

## 📁 Directory Structure

```
nodes/
├── src/                          # Source code
│   ├── nodes/                    # Custom nodes
│   ├── credentials/              # Custom credentials
│   └── index.ts                  # Main entry point
├── dist/                         # Compiled output
├── templates/                    # Node templates
│   ├── ExampleNode.node.ts       # Example node template
│   └── ExampleApi.credentials.ts # Example credential template
├── examples/                     # Example implementations
├── scripts/                      # Build and development scripts
│   └── build.sh                  # Main build script
├── tests/                        # Test files
├── package.json                  # Dependencies and scripts
├── tsconfig.json                 # TypeScript configuration
├── .eslintrc.js                  # ESLint configuration
├── .prettierrc                   # Prettier configuration
├── jest.config.js                # Jest test configuration
└── README.md                     # This file
```

## 🛠️ Development Workflow

### 1. Creating a New Node

#### Step 1: Create Node File
```bash
# Create a new node file
touch src/nodes/MyApiNode.node.ts
```

#### Step 2: Implement Node Class
```typescript
import {
    IExecuteFunctions,
    INodeExecutionData,
    INodeType,
    INodeTypeDescription,
} from 'n8n-workflow';

export class MyApiNode implements INodeType {
    description: INodeTypeDescription = {
        displayName: 'My API Node',
        name: 'myApiNode',
        group: ['transform'],
        version: 1,
        description: 'Custom node for My API',
        defaults: {
            name: 'My API Node',
        },
        inputs: ['main'],
        outputs: ['main'],
        properties: [
            // Define node parameters here
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        // Implement node logic here
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];
        
        // Process items...
        
        return [returnData];
    }
}
```

#### Step 3: Create Credentials (if needed)
```bash
# Create credentials file
touch src/credentials/MyApiCredentials.credentials.ts
```

#### Step 4: Build and Test
```bash
# Build the node
npm run build

# Test the node
npm test

# Validate code quality
npm run lint
npm run format
```

### 2. Development Commands

```bash
# Development workflow
npm run dev                    # Start development mode (watch)
npm run build                  # Build all nodes
npm run build:watch            # Build and watch for changes
npm run test                   # Run tests
npm run test:watch             # Run tests in watch mode
npm run lint                   # Run ESLint
npm run lint:fix               # Fix ESLint issues
npm run format                 # Format code with Prettier
npm run validate               # Run all validation checks

# Using build script
./scripts/build.sh build       # Build nodes
./scripts/build.sh watch       # Watch mode
./scripts/build.sh test        # Run tests
./scripts/build.sh validate    # Full validation
./scripts/build.sh clean       # Clean build artifacts
```

### 3. Testing Your Nodes

#### Unit Testing
```typescript
// tests/nodes/MyApiNode.test.ts
import { MyApiNode } from '../../src/nodes/MyApiNode.node';

describe('MyApiNode', () => {
    let node: MyApiNode;

    beforeEach(() => {
        node = new MyApiNode();
    });

    test('should have correct description', () => {
        expect(node.description.displayName).toBe('My API Node');
        expect(node.description.name).toBe('myApiNode');
    });

    // Add more tests...
});
```

#### Integration Testing
```bash
# Build and mount in N8N for testing
./scripts/build.sh build
cd ..
docker compose up -d

# Access N8N at http://localhost:5678
# Your custom nodes will be available in the node palette
```

## 🔧 Configuration Files

### TypeScript Configuration (`tsconfig.json`)
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "strict": true,
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
```

### ESLint Configuration (`.eslintrc.js`)
```javascript
module.exports = {
    extends: [
        '@typescript-eslint/recommended',
        'prettier',
    ],
    parser: '@typescript-eslint/parser',
    plugins: ['@typescript-eslint'],
    rules: {
        // Custom rules
    },
};
```

### Jest Configuration (`jest.config.js`)
```javascript
module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    roots: ['<rootDir>/src', '<rootDir>/tests'],
    testMatch: ['**/*.test.ts'],
    collectCoverageFrom: [
        'src/**/*.ts',
        '!src/**/*.d.ts',
    ],
};
```

## 🐳 Docker Integration

### Mounting Custom Nodes

The N8N-R8 Docker setup automatically mounts custom nodes when they're built:

```yaml
# docker-compose.yml (already configured)
services:
  n8n:
    volumes:
      - ./nodes/dist:/home/node/.n8n/custom
```

### Development Container

For development, you can use a separate container:

```bash
# Create development container
docker run -it --rm \
  -v $(pwd)/nodes:/nodes \
  -w /nodes \
  node:18-alpine \
  sh

# Inside container
npm install
npm run build
npm test
```

## 📚 Node Development Guidelines

### 1. Node Structure Best Practices

#### Naming Conventions
- **Node files**: `MyNodeName.node.ts`
- **Credential files**: `MyCredentialName.credentials.ts`
- **Class names**: `MyNodeName` (PascalCase)
- **Node names**: `myNodeName` (camelCase)

#### Node Properties
```typescript
description: INodeTypeDescription = {
    displayName: 'Human Readable Name',
    name: 'machineReadableName',
    icon: 'file:icon.svg',           // Custom icon
    group: ['transform'],            // Node category
    version: 1,                      // Node version
    subtitle: '={{$parameter["operation"]}}', // Dynamic subtitle
    description: 'Node description',
    defaults: {
        name: 'Default Node Name',
    },
    inputs: ['main'],                // Input types
    outputs: ['main'],               // Output types
    credentials: [                   // Required credentials
        {
            name: 'myApiCredentials',
            required: true,
        },
    ],
    properties: [                    // Node parameters
        // Parameter definitions
    ],
};
```

### 2. Parameter Types

#### Common Parameter Types
```typescript
// String input
{
    displayName: 'Text Input',
    name: 'textInput',
    type: 'string',
    default: '',
    placeholder: 'Enter text...',
    description: 'Text input description',
}

// Number input
{
    displayName: 'Number Input',
    name: 'numberInput',
    type: 'number',
    default: 0,
    typeOptions: {
        minValue: 0,
        maxValue: 100,
    },
}

// Boolean checkbox
{
    displayName: 'Enable Feature',
    name: 'enableFeature',
    type: 'boolean',
    default: false,
}

// Dropdown options
{
    displayName: 'Operation',
    name: 'operation',
    type: 'options',
    options: [
        {
            name: 'Create',
            value: 'create',
            description: 'Create a new item',
        },
        {
            name: 'Update',
            value: 'update',
            description: 'Update an existing item',
        },
    ],
    default: 'create',
}

// Collection of fields
{
    displayName: 'Additional Fields',
    name: 'additionalFields',
    type: 'collection',
    placeholder: 'Add Field',
    default: {},
    options: [
        {
            displayName: 'Field Name',
            name: 'fieldName',
            type: 'string',
            default: '',
        },
    ],
}
```

#### Conditional Display
```typescript
{
    displayName: 'User ID',
    name: 'userId',
    type: 'string',
    displayOptions: {
        show: {
            resource: ['user'],
            operation: ['get', 'update'],
        },
        hide: {
            resource: ['post'],
        },
    },
    default: '',
}
```

### 3. Error Handling

```typescript
async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
    const items = this.getInputData();
    const returnData: INodeExecutionData[] = [];

    for (let i = 0; i < items.length; i++) {
        try {
            // Node logic here
            const responseData = await this.processItem(i);
            
            const executionData = this.helpers.constructExecutionMetaData(
                this.helpers.returnJsonArray(responseData),
                { itemData: { item: i } },
            );
            
            returnData.push(...executionData);
        } catch (error) {
            if (this.continueOnFail()) {
                // Continue processing other items
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
```

### 4. HTTP Requests

```typescript
// Using the HTTP request helper
const response = await this.helpers.request({
    method: 'GET',
    url: 'https://api.example.com/data',
    headers: {
        'Authorization': `Bearer ${credentials.token}`,
        'Content-Type': 'application/json',
    },
    json: true,
});

// Using requestWithAuthentication (with credentials)
const response = await this.helpers.requestWithAuthentication.call(
    this,
    'myApiCredentials',
    {
        method: 'POST',
        url: 'https://api.example.com/data',
        body: requestData,
        json: true,
    },
);
```

## 🧪 Testing Strategies

### 1. Unit Tests
```typescript
// Test node properties
describe('Node Properties', () => {
    test('should have correct display name', () => {
        const node = new MyNode();
        expect(node.description.displayName).toBe('My Node');
    });
});

// Test parameter validation
describe('Parameter Validation', () => {
    test('should validate required parameters', () => {
        // Test parameter validation logic
    });
});
```

### 2. Integration Tests
```typescript
// Mock N8N execution context
const mockExecuteFunctions = {
    getInputData: jest.fn(),
    getNodeParameter: jest.fn(),
    helpers: {
        request: jest.fn(),
        returnJsonArray: jest.fn(),
        constructExecutionMetaData: jest.fn(),
    },
};

describe('Node Execution', () => {
    test('should process data correctly', async () => {
        // Setup mocks
        mockExecuteFunctions.getInputData.mockReturnValue([{ json: { test: 'data' } }]);
        
        const node = new MyNode();
        const result = await node.execute.call(mockExecuteFunctions);
        
        expect(result).toBeDefined();
        // Add more assertions
    });
});
```

### 3. End-to-End Testing
```bash
# Build and deploy to test environment
./scripts/build.sh build
docker compose up -d

# Test in N8N UI
# 1. Create a workflow with your custom node
# 2. Configure the node parameters
# 3. Execute the workflow
# 4. Verify the output
```

## 🚀 Deployment

### 1. Building for Production
```bash
# Production build
./scripts/build.sh build --production

# Validate before deployment
./scripts/build.sh validate

# Package for distribution
./scripts/build.sh package
```

### 2. Publishing to npm (Optional)
```bash
# Update version
npm version patch

# Publish to npm registry
npm publish

# Install in other N8N instances
npm install n8n-r8-custom-nodes
```

### 3. Docker Deployment
```bash
# Build nodes
./scripts/build.sh build --production

# Start N8N with custom nodes
cd ..
docker compose up -d

# Custom nodes will be automatically available
```

## 🔍 Debugging

### 1. Development Debugging
```typescript
// Add debug logging
console.log('Debug info:', data);

// Use N8N logger
this.logger.debug('Debug message', { data });
this.logger.info('Info message');
this.logger.warn('Warning message');
this.logger.error('Error message', error);
```

### 2. Container Debugging
```bash
# Access N8N container
docker exec -it n8n /bin/sh

# Check mounted custom nodes
ls -la /home/node/.n8n/custom/

# View N8N logs
docker logs n8n -f
```

### 3. Common Issues

#### Node Not Appearing
- Check build output in `dist/` directory
- Verify Docker volume mount
- Restart N8N container
- Check N8N logs for errors

#### TypeScript Errors
```bash
# Check TypeScript compilation
npx tsc --noEmit

# Fix common issues
npm run lint:fix
npm run format
```

#### Runtime Errors
- Check parameter validation
- Verify credential configuration
- Test API endpoints manually
- Add error handling and logging

## 📖 Resources

### N8N Documentation
- [N8N Node Development](https://docs.n8n.io/integrations/creating-nodes/)
- [N8N API Reference](https://docs.n8n.io/integrations/creating-nodes/code/)
- [N8N Community Nodes](https://docs.n8n.io/integrations/community-nodes/)

### TypeScript Resources
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [TypeScript ESLint](https://typescript-eslint.io/)

### Testing Resources
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Testing Best Practices](https://github.com/goldbergyoni/javascript-testing-best-practices)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Develop your custom node
4. Add tests and documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

Happy node development! 🎉
