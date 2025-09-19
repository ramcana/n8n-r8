# Contributing to N8N-R8

Thank you for your interest in contributing to N8N-R8! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue templates** provided
3. **Provide detailed information** including:
   - Operating system and version
   - Docker and Docker Compose versions
   - Steps to reproduce the issue
   - Expected vs actual behavior
   - Relevant logs or error messages

### Suggesting Features

We welcome feature suggestions! Please:

1. **Check existing feature requests** first
2. **Use the feature request template**
3. **Explain the use case** and benefits
4. **Consider implementation complexity**

### Pull Requests

1. **Fork the repository** and create a feature branch
2. **Follow the coding standards** outlined below
3. **Test your changes thoroughly**
4. **Update documentation** as needed
5. **Submit a pull request** using the provided template

## 🛠️ Development Setup

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- Text editor or IDE

### Local Development

1. **Clone your fork:**
   ```bash
   git clone https://github.com/your-username/n8n-r8.git
   cd n8n-r8
   ```

2. **Set up environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Start development environment:**
   ```bash
   make quick-dev-full
   ```

4. **Make your changes and test:**
   ```bash
   make test
   make health
   ```

### Custom Nodes Development

For developing custom N8N nodes:

1. **Navigate to nodes directory:**
   ```bash
   cd nodes
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start development mode:**
   ```bash
   npm run dev
   ```

4. **Build nodes:**
   ```bash
   npm run build
   ```

## 📋 Coding Standards

### General Guidelines

- **Follow existing code style** and conventions
- **Use meaningful variable and function names**
- **Add comments for complex logic**
- **Keep functions small and focused**
- **Handle errors gracefully**

### Shell Scripts

- **Use `#!/bin/bash` shebang**
- **Set `set -euo pipefail` for safety**
- **Quote variables properly**
- **Use `shellcheck` for linting**
- **Follow the existing script structure**

Example:
```bash
#!/bin/bash
set -euo pipefail

# Script description
# Usage: ./script.sh [options]

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

main() {
    local option="${1:-}"
    
    case "$option" in
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $option"
            exit 1
            ;;
    esac
}

show_help() {
    cat << EOF
Usage: $0 [options]

Options:
    -h, --help    Show this help message

EOF
}

main "$@"
```

### Docker Compose

- **Use version '3.8'** consistently
- **Pin image versions** (no `:latest`)
- **Add health checks** for all services
- **Use resource limits**
- **Follow security best practices**

### JavaScript/TypeScript (Custom Nodes)

- **Use Prettier** for formatting (see `nodes/.prettierrc`)
- **Follow TypeScript best practices**
- **Add JSDoc comments** for public methods
- **Use meaningful interface names**
- **Handle async operations properly**

Example:
```typescript
/**
 * Example N8N node implementation
 */
export class ExampleNode implements INodeType {
    description: INodeTypeDescription = {
        displayName: 'Example Node',
        name: 'exampleNode',
        group: ['transform'],
        version: 1,
        description: 'Example node for demonstration',
        defaults: {
            name: 'Example Node',
        },
        inputs: ['main'],
        outputs: ['main'],
        properties: [
            // Node properties
        ],
    };

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        // Implementation
    }
}
```

### Documentation

- **Update README.md** for user-facing changes
- **Add inline comments** for complex code
- **Update relevant documentation files**
- **Use clear, concise language**
- **Include examples where helpful**

## 🧪 Testing

### Manual Testing

Before submitting a PR, test:

1. **Basic functionality:**
   ```bash
   make start-nginx
   make health
   make logs
   ```

2. **Different configurations:**
   ```bash
   make start-traefik
   make start-monitoring
   ```

3. **Cleanup and reset:**
   ```bash
   make stop
   make reset
   ```

### Automated Testing

Run the test suite:
```bash
make test
```

For custom nodes:
```bash
cd nodes
npm test
```

## 📝 Documentation Updates

When making changes that affect users:

1. **Update README.md** with new features or changes
2. **Update relevant documentation** in `docs/`
3. **Add examples** for new functionality
4. **Update the changelog** (see CHANGELOG.md)

## 🔒 Security Considerations

When contributing:

- **Never commit secrets** or credentials
- **Use environment variables** for configuration
- **Follow security best practices**
- **Report security issues** privately (see SECURITY.md)
- **Test security configurations**

## 📋 Pull Request Process

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the guidelines above

3. **Test thoroughly:**
   ```bash
   make test
   make health
   ```

4. **Commit with clear messages:**
   ```bash
   git commit -m "feat: add new monitoring dashboard"
   ```

5. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a pull request** using the template

### PR Requirements

- [ ] Code follows the style guidelines
- [ ] Self-review of the code completed
- [ ] Changes are tested and working
- [ ] Documentation updated if needed
- [ ] No breaking changes (or clearly documented)
- [ ] Commit messages are clear and descriptive

## 🏷️ Commit Message Format

Use conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(monitoring): add Grafana dashboard for N8N metrics
fix(docker): resolve PostgreSQL connection timeout issue
docs(readme): update installation instructions
```

## 🎯 Areas for Contribution

We especially welcome contributions in these areas:

### High Priority
- **Security improvements** and hardening
- **Performance optimizations**
- **Bug fixes** and stability improvements
- **Documentation improvements**

### Medium Priority
- **New custom nodes** for N8N
- **Monitoring enhancements**
- **Backup and restore improvements**
- **CI/CD pipeline enhancements**

### Low Priority
- **UI/UX improvements** for scripts
- **Additional deployment options**
- **Integration with other tools**
- **Example workflows and use cases**

## 🆘 Getting Help

If you need help while contributing:

1. **Check the documentation** first
2. **Search existing issues** and discussions
3. **Ask questions** in GitHub issues
4. **Join the community** discussions

## 📄 License

By contributing to N8N-R8, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be recognized in:
- **README.md** contributors section
- **CHANGELOG.md** for significant contributions
- **GitHub contributors** page

Thank you for helping make N8N-R8 better! 🚀
