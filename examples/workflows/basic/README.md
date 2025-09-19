# Basic Workflow Examples

This directory contains simple, foundational workflow examples that demonstrate core N8N functionality.

## 📋 Available Workflows

### 1. Webhook to Email Notification
**File**: `webhook-to-email.json`

**Description**: A simple workflow that receives contact form submissions via webhook and sends email notifications.

**Features**:
- HTTP webhook trigger
- Data formatting and validation
- Email notification sending
- Error handling

**Use Case**: Contact forms, lead capture, customer inquiries

**Setup**:
1. Import the workflow into N8N
2. Configure email credentials
3. Activate the workflow
4. Test with: 
   ```bash
   curl -X POST http://localhost:5678/webhook/contact-form \
     -H "Content-Type: application/json" \
     -d '{
       "name": "John Doe",
       "email": "john@example.com", 
       "message": "Hello, I am interested in your services."
     }'
   ```

## 🔧 How to Use These Examples

### 1. Import Workflow
1. Open N8N interface
2. Click "Import from File" or "Import from URL"
3. Select the JSON file
4. Configure any required credentials
5. Activate the workflow

### 2. Customize for Your Needs
- Modify webhook paths
- Update email templates
- Add additional processing steps
- Configure different notification channels

### 3. Test Workflows
- Use the provided curl commands
- Test with different data scenarios
- Monitor execution logs
- Verify error handling

## 📚 Learning Objectives

These basic examples help you understand:
- **Webhook Triggers**: How to receive HTTP requests
- **Data Transformation**: Processing and formatting data
- **External Integrations**: Connecting to third-party services
- **Error Handling**: Managing workflow failures
- **Best Practices**: Following N8N conventions

## 🚀 Next Steps

After mastering these basic workflows:
1. Explore intermediate examples
2. Learn about advanced node configurations
3. Implement custom error handling
4. Add monitoring and logging
5. Scale for production use

## 💡 Tips for Beginners

1. **Start Simple**: Begin with basic workflows and add complexity gradually
2. **Test Thoroughly**: Always test workflows with various input scenarios
3. **Use Expressions**: Learn N8N's expression syntax for dynamic data
4. **Monitor Executions**: Check execution logs to understand workflow behavior
5. **Document Workflows**: Add descriptions and comments to your workflows

## 🔍 Troubleshooting

### Common Issues
- **Webhook not triggering**: Check URL and HTTP method
- **Email not sending**: Verify credentials and SMTP settings
- **Data not formatting**: Check expression syntax and data structure
- **Workflow not activating**: Ensure all required fields are configured

### Debugging Tips
- Use the "Execute Workflow" button to test manually
- Check the execution log for detailed error messages
- Verify input data structure matches expectations
- Test individual nodes before connecting them
