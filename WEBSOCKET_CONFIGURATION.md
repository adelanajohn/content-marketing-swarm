# WebSocket Configuration Guide

## Overview

This guide provides comprehensive documentation for the WebSocket streaming endpoint used in the Content Marketing Swarm application. The WebSocket endpoint enables real-time streaming of content generation updates from the backend to the frontend.

## WebSocket Endpoint

### URL
```
wss://api.blacksteep.com/ws/stream-generation
```

### Protocol
- **Protocol**: WebSocket (WSS - WebSocket Secure)
- **Transport**: HTTPS/TLS
- **Port**: 443 (standard HTTPS port)

## Message Format

### Connection Flow

1. **Client initiates connection** to `wss://api.blacksteep.com/ws/stream-generation`
2. **Server sends connection confirmation** with client ID
3. **Client sends generation request** with prompt and parameters
4. **Server streams updates** as content is generated
5. **Server sends completion message** when generation finishes
6. **Connection closes** gracefully

### Message Types

#### 1. Connection Confirmation (Server → Client)

Sent immediately after WebSocket connection is established.

```json
{
  "type": "connected",
  "client_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "message": "WebSocket connection established"
}
```

**Fields**:
- `type`: Always "connected"
- `client_id`: Unique identifier for this connection (UUID format)
- `message`: Human-readable confirmation message

#### 2. Generation Request (Client → Server)

Sent by client to initiate content generation.

```json
{
  "prompt": "Create social media content about AI innovations",
  "user_id": "user-123",
  "brand_profile_id": "brand-456"
}
```

**Fields**:
- `prompt`: Content generation prompt (required)
- `user_id`: User identifier (required)
- `brand_profile_id`: Brand profile to use for generation (optional)

#### 3. Agent Start (Server → Client)

Sent when an agent begins processing.

```json
{
  "type": "agent_start",
  "agent": "ResearchAgent",
  "message": "Starting research phase...",
  "timestamp": "2025-11-25T11:30:00Z"
}
```

**Fields**:
- `type`: Always "agent_start"
- `agent`: Name of the agent (ResearchAgent, CreatorAgent, SchedulerAgent)
- `message`: Description of what the agent is doing
- `timestamp`: ISO 8601 timestamp

#### 4. Content Chunk (Server → Client)

Sent as content is generated in real-time.

```json
{
  "type": "content_chunk",
  "agent": "CreatorAgent",
  "content": "Here's an engaging social media post about...",
  "timestamp": "2025-11-25T11:30:15Z"
}
```

**Fields**:
- `type`: Always "content_chunk"
- `agent`: Name of the agent generating content
- `content`: Partial or complete content text
- `timestamp`: ISO 8601 timestamp

#### 5. Agent Complete (Server → Client)

Sent when an agent finishes processing.

```json
{
  "type": "agent_complete",
  "agent": "ResearchAgent",
  "message": "Research phase completed",
  "timestamp": "2025-11-25T11:30:30Z"
}
```

**Fields**:
- `type`: Always "agent_complete"
- `agent`: Name of the agent that completed
- `message`: Completion message
- `timestamp`: ISO 8601 timestamp

#### 6. Complete (Server → Client)

Sent when entire generation process is complete.

```json
{
  "type": "complete",
  "message": "Content generation completed successfully",
  "timestamp": "2025-11-25T11:31:00Z"
}
```

**Fields**:
- `type`: Always "complete"
- `message`: Completion message
- `timestamp`: ISO 8601 timestamp

#### 7. Error (Server → Client)

Sent when an error occurs during generation.

```json
{
  "type": "error",
  "message": "Error during generation: Invalid prompt format",
  "timestamp": "2025-11-25T11:30:45Z"
}
```

**Fields**:
- `type`: Always "error"
- `message`: Error description
- `timestamp`: ISO 8601 timestamp

#### 8. Shutdown (Server → Client)

Sent when server is shutting down gracefully.

```json
{
  "type": "shutdown",
  "message": "Server is shutting down, please reconnect"
}
```

**Fields**:
- `type`: Always "shutdown"
- `message`: Shutdown notification

## JavaScript Connection Examples

### Basic Connection (Vanilla JavaScript)

```javascript
// Create WebSocket connection
const ws = new WebSocket('wss://api.blacksteep.com/ws/stream-generation');

// Connection opened
ws.addEventListener('open', (event) => {
  console.log('WebSocket connected');
  
  // Send generation request
  ws.send(JSON.stringify({
    prompt: 'Create social media content about AI',
    user_id: 'user-123',
    brand_profile_id: 'brand-456'
  }));
});

// Listen for messages
ws.addEventListener('message', (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
  
  switch(data.type) {
    case 'connected':
      console.log('Connection confirmed, client ID:', data.client_id);
      break;
    case 'agent_start':
      console.log(`${data.agent} started:`, data.message);
      break;
    case 'content_chunk':
      console.log('Content:', data.content);
      break;
    case 'agent_complete':
      console.log(`${data.agent} completed`);
      break;
    case 'complete':
      console.log('Generation complete!');
      ws.close();
      break;
    case 'error':
      console.error('Error:', data.message);
      break;
  }
});

// Handle errors
ws.addEventListener('error', (error) => {
  console.error('WebSocket error:', error);
});

// Handle connection close
ws.addEventListener('close', (event) => {
  console.log('WebSocket closed:', event.code, event.reason);
});
```

### React Hook Example

```javascript
import { useEffect, useState, useRef } from 'react';

function useWebSocket(url) {
  const [messages, setMessages] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  const ws = useRef(null);

  useEffect(() => {
    // Create WebSocket connection
    ws.current = new WebSocket(url);

    ws.current.onopen = () => {
      console.log('WebSocket connected');
      setIsConnected(true);
    };

    ws.current.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setMessages(prev => [...prev, data]);
    };

    ws.current.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    ws.current.onclose = () => {
      console.log('WebSocket disconnected');
      setIsConnected(false);
    };

    // Cleanup on unmount
    return () => {
      if (ws.current) {
        ws.current.close();
      }
    };
  }, [url]);

  const sendMessage = (message) => {
    if (ws.current && ws.current.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(message));
    }
  };

  return { messages, isConnected, sendMessage };
}

// Usage in component
function ContentGenerator() {
  const { messages, isConnected, sendMessage } = useWebSocket(
    'wss://api.blacksteep.com/ws/stream-generation'
  );

  const handleGenerate = () => {
    sendMessage({
      prompt: 'Create social media content about AI',
      user_id: 'user-123',
      brand_profile_id: 'brand-456'
    });
  };

  return (
    <div>
      <button onClick={handleGenerate} disabled={!isConnected}>
        Generate Content
      </button>
      <div>
        {messages.map((msg, idx) => (
          <div key={idx}>{msg.type}: {msg.message || msg.content}</div>
        ))}
      </div>
    </div>
  );
}
```

### Automatic Reconnection Example

```javascript
class WebSocketClient {
  constructor(url, options = {}) {
    this.url = url;
    this.reconnectInterval = options.reconnectInterval || 5000;
    this.maxReconnectAttempts = options.maxReconnectAttempts || 5;
    this.reconnectAttempts = 0;
    this.ws = null;
    this.messageHandlers = [];
  }

  connect() {
    this.ws = new WebSocket(this.url);

    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.reconnectAttempts = 0;
    };

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.messageHandlers.forEach(handler => handler(data));
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    this.ws.onclose = (event) => {
      console.log('WebSocket closed:', event.code);
      
      // Attempt to reconnect
      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        this.reconnectAttempts++;
        console.log(`Reconnecting... (attempt ${this.reconnectAttempts})`);
        setTimeout(() => this.connect(), this.reconnectInterval);
      } else {
        console.error('Max reconnection attempts reached');
      }
    };
  }

  send(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.error('WebSocket is not connected');
    }
  }

  onMessage(handler) {
    this.messageHandlers.push(handler);
  }

  close() {
    if (this.ws) {
      this.ws.close();
    }
  }
}

// Usage
const client = new WebSocketClient('wss://api.blacksteep.com/ws/stream-generation', {
  reconnectInterval: 3000,
  maxReconnectAttempts: 10
});

client.onMessage((data) => {
  console.log('Received:', data);
});

client.connect();

// Send message
client.send({
  prompt: 'Create social media content',
  user_id: 'user-123'
});
```

## CORS Configuration

### Overview

Cross-Origin Resource Sharing (CORS) controls which origins can access the WebSocket endpoint. The backend is configured to allow connections from specific origins.

### Allowed Origins

The following origins are allowed to connect to the WebSocket endpoint:

1. **Local Development**: `http://localhost:3000`
2. **CloudFront Distribution**: `https://d2b386ss3jk33z.cloudfront.net`
3. **Custom Domain**: `https://api.blacksteep.com`

### Configuration

CORS origins are configured via the `CORS_ORIGINS` environment variable in the ECS task definition:

```hcl
# infrastructure/terraform/modules/ecs/service.tf
environment = [
  {
    name  = "CORS_ORIGINS"
    value = "http://localhost:3000,https://d2b386ss3jk33z.cloudfront.net,https://api.blacksteep.com"
  }
]
```

### Adding New Origins

To add a new origin:

1. Update the `CORS_ORIGINS` environment variable in `infrastructure/terraform/modules/ecs/service.tf`
2. Add the new origin to the comma-separated list
3. Apply Terraform changes: `terraform apply`
4. Wait for ECS to deploy the new task definition

Example:
```hcl
{
  name  = "CORS_ORIGINS"
  value = "http://localhost:3000,https://d2b386ss3jk33z.cloudfront.net,https://api.blacksteep.com,https://new-domain.com"
}
```

### CORS and WebSockets

Note: WebSocket connections don't use traditional CORS headers. However, the browser performs an origin check during the initial HTTP upgrade request. The backend validates the `Origin` header against the allowed origins list.

## ALB Configuration for WebSocket Support

### Overview

The Application Load Balancer (ALB) is configured to properly handle WebSocket connections, which require special configuration compared to standard HTTP traffic.

### Key Configuration Elements

#### 1. Sticky Sessions (Session Affinity)

WebSocket connections are long-lived and stateful. Sticky sessions ensure that all frames from a WebSocket connection are routed to the same backend target.

```hcl
# infrastructure/terraform/modules/ecs/main.tf
resource "aws_lb_target_group" "main" {
  # ... other configuration ...
  
  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400  # 24 hours in seconds
  }
}
```

**Configuration**:
- **Type**: `lb_cookie` (load balancer-generated cookie)
- **Enabled**: `true`
- **Duration**: 86400 seconds (24 hours)

**Why it's needed**: Without sticky sessions, the ALB might route different WebSocket frames to different backend tasks, causing connection failures.

#### 2. Deregistration Delay

When ECS tasks are being replaced (during deployments), the deregistration delay allows existing WebSocket connections to complete gracefully.

```hcl
resource "aws_lb_target_group" "main" {
  # ... other configuration ...
  
  deregistration_delay = 300  # 5 minutes in seconds
}
```

**Configuration**:
- **Delay**: 300 seconds (5 minutes)

**Why it's needed**: Gives active WebSocket connections time to complete before the task is terminated, preventing abrupt disconnections during deployments.

#### 3. Health Checks

The ALB performs health checks to ensure backend tasks are healthy before routing traffic to them.

```hcl
resource "aws_lb_target_group" "main" {
  # ... other configuration ...
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }
}
```

**Configuration**:
- **Path**: `/health` (HTTP endpoint, not WebSocket)
- **Protocol**: HTTP
- **Interval**: 30 seconds
- **Healthy threshold**: 2 consecutive successes
- **Unhealthy threshold**: 3 consecutive failures

**Why it's needed**: Ensures the ALB only routes traffic to healthy backend tasks.

#### 4. HTTPS Listener

The ALB listener on port 443 handles HTTPS traffic and WebSocket upgrade requests.

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

**Configuration**:
- **Port**: 443 (HTTPS)
- **Protocol**: HTTPS
- **SSL Policy**: TLS 1.3 and 1.2
- **Action**: Forward to target group

**Why it's needed**: WebSocket Secure (WSS) connections start as HTTPS requests with an upgrade header. The ALB forwards these to the backend, which completes the WebSocket handshake.

### WebSocket Upgrade Flow

1. **Client sends HTTPS request** with WebSocket upgrade headers:
   ```
   GET /ws/stream-generation HTTP/1.1
   Host: api.blacksteep.com
   Upgrade: websocket
   Connection: Upgrade
   Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
   Sec-WebSocket-Version: 13
   ```

2. **ALB forwards request** to backend target (ECS task)

3. **Backend responds** with HTTP 101 Switching Protocols:
   ```
   HTTP/1.1 101 Switching Protocols
   Upgrade: websocket
   Connection: Upgrade
   Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
   ```

4. **Connection upgraded** to WebSocket protocol

5. **ALB maintains connection** using sticky sessions

### Verifying ALB Configuration

You can verify the ALB configuration in the AWS Console:

1. Navigate to **EC2 → Load Balancers**
2. Select your ALB (e.g., `content-marketing-swarm-dev-alb`)
3. Go to **Target Groups** tab
4. Select your target group
5. Check **Attributes** tab:
   - Stickiness should be enabled
   - Deregistration delay should be 300 seconds
6. Check **Health checks** tab:
   - Path should be `/health`
   - Protocol should be HTTP

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: WebSocket Connection Fails with 404 Not Found

**Symptoms**:
- Browser console shows: "WebSocket connection failed"
- Network tab shows 404 status code
- Error: "WebSocket is closed before the connection is established"

**Possible Causes**:
1. WebSocket endpoint not registered in backend
2. Backend application not running
3. Incorrect URL path

**Solutions**:

1. **Verify backend is running**:
   ```bash
   # Check ECS tasks are running
   aws ecs list-tasks --cluster content-marketing-swarm-dev
   
   # Check task health
   aws ecs describe-tasks --cluster content-marketing-swarm-dev --tasks <task-arn>
   ```

2. **Check backend logs**:
   ```bash
   # View CloudWatch logs
   aws logs tail /ecs/content-marketing-swarm-dev --follow
   ```
   
   Look for: "Application startup complete" and router registration messages

3. **Verify WebSocket router is registered**:
   Check `backend/app/main.py` includes:
   ```python
   from app.api.websocket import router as websocket_router
   app.include_router(websocket_router)
   ```

4. **Test endpoint directly**:
   ```bash
   # Using wscat
   wscat -c wss://api.blacksteep.com/ws/stream-generation
   ```

#### Issue 2: CORS Error in Browser Console

**Symptoms**:
- Browser console shows CORS error
- Error: "Access to WebSocket at 'wss://...' from origin '...' has been blocked by CORS policy"

**Possible Causes**:
1. Frontend origin not in CORS allowed origins list
2. CORS_ORIGINS environment variable not set correctly

**Solutions**:

1. **Check current CORS configuration**:
   ```bash
   # View ECS task definition
   aws ecs describe-task-definition --task-definition content-marketing-swarm-dev
   ```
   
   Look for `CORS_ORIGINS` environment variable

2. **Add missing origin**:
   Edit `infrastructure/terraform/modules/ecs/service.tf`:
   ```hcl
   {
     name  = "CORS_ORIGINS"
     value = "http://localhost:3000,https://d2b386ss3jk33z.cloudfront.net,https://api.blacksteep.com,https://your-new-origin.com"
   }
   ```

3. **Apply Terraform changes**:
   ```bash
   cd infrastructure/terraform
   terraform apply
   ```

4. **Verify new task is deployed**:
   ```bash
   # Wait for new task to be running
   aws ecs list-tasks --cluster content-marketing-swarm-dev
   ```

#### Issue 3: Connection Drops After a Few Seconds

**Symptoms**:
- WebSocket connects successfully
- Connection closes unexpectedly after 10-30 seconds
- No error message or generic close code

**Possible Causes**:
1. ALB sticky sessions not enabled
2. Connection timeout too short
3. Backend task being replaced

**Solutions**:

1. **Verify sticky sessions are enabled**:
   ```bash
   # Check target group attributes
   aws elbv2 describe-target-group-attributes \
     --target-group-arn <target-group-arn>
   ```
   
   Look for:
   ```json
   {
     "Key": "stickiness.enabled",
     "Value": "true"
   }
   ```

2. **Check ALB target group configuration**:
   In `infrastructure/terraform/modules/ecs/main.tf`:
   ```hcl
   stickiness {
     type            = "lb_cookie"
     enabled         = true
     cookie_duration = 86400
   }
   ```

3. **Verify deregistration delay**:
   ```hcl
   deregistration_delay = 300
   ```

4. **Implement client-side reconnection**:
   ```javascript
   ws.addEventListener('close', (event) => {
     console.log('Connection closed, reconnecting...');
     setTimeout(() => {
       // Reconnect logic
       connectWebSocket();
     }, 3000);
   });
   ```

#### Issue 4: Cannot Connect to wss://api.blacksteep.com

**Symptoms**:
- DNS resolution fails
- SSL/TLS certificate errors
- Connection timeout

**Possible Causes**:
1. DNS not configured correctly
2. Certificate not valid
3. ALB not accessible

**Solutions**:

1. **Verify DNS resolution**:
   ```bash
   # Check DNS resolves to ALB
   nslookup api.blacksteep.com
   dig api.blacksteep.com
   ```

2. **Check certificate**:
   ```bash
   # Verify SSL certificate
   openssl s_client -connect api.blacksteep.com:443 -servername api.blacksteep.com
   ```

3. **Test ALB directly**:
   ```bash
   # Get ALB DNS name
   aws elbv2 describe-load-balancers --names content-marketing-swarm-dev-alb
   
   # Test connection to ALB
   curl -I https://<alb-dns-name>/health
   ```

4. **Verify Route53 record**:
   Check that `api.blacksteep.com` points to the ALB DNS name

#### Issue 5: Messages Not Received

**Symptoms**:
- WebSocket connects successfully
- No messages received after sending request
- Connection stays open but silent

**Possible Causes**:
1. Backend not processing request
2. Message format incorrect
3. Backend error not being sent to client

**Solutions**:

1. **Check message format**:
   Ensure request includes required fields:
   ```json
   {
     "prompt": "Your prompt here",
     "user_id": "user-123",
     "brand_profile_id": "brand-456"
   }
   ```

2. **Check backend logs**:
   ```bash
   aws logs tail /ecs/content-marketing-swarm-dev --follow
   ```
   
   Look for error messages or exceptions

3. **Test with diagnostic script**:
   ```bash
   cd backend
   python diagnose_websocket.py
   ```

4. **Verify agents are configured**:
   Check that research, creator, and scheduler agents are properly initialized

#### Issue 6: High Latency or Slow Streaming

**Symptoms**:
- Messages arrive with significant delay
- Streaming feels sluggish
- Content appears in large chunks instead of smoothly

**Possible Causes**:
1. Backend processing slow
2. Network congestion
3. Too many concurrent connections

**Solutions**:

1. **Check ECS task metrics**:
   ```bash
   # View CPU and memory usage
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization \
     --dimensions Name=ServiceName,Value=content-marketing-swarm-dev \
     --start-time 2025-11-25T00:00:00Z \
     --end-time 2025-11-25T23:59:59Z \
     --period 300 \
     --statistics Average
   ```

2. **Scale up ECS service**:
   ```bash
   aws ecs update-service \
     --cluster content-marketing-swarm-dev \
     --service content-marketing-swarm-dev \
     --desired-count 3
   ```

3. **Check ALB metrics**:
   Monitor target response time in CloudWatch

4. **Optimize backend processing**:
   Review agent code for performance bottlenecks

### Diagnostic Tools

#### 1. WebSocket Diagnostic Script

Run the diagnostic script to check WebSocket configuration:

```bash
cd backend
python diagnose_websocket.py
```

This script checks:
- WebSocket endpoint registration
- CORS configuration
- ALB target group settings
- Connection test

#### 2. Live WebSocket Test

Test WebSocket connectivity:

```bash
cd backend
python test_live_websocket.py
```

#### 3. Integration Tests

Run integration tests:

```bash
cd backend
pytest tests/test_websocket_connectivity.py -v
```

#### 4. Command-Line Tools

**Using wscat**:
```bash
# Install wscat
npm install -g wscat

# Connect to WebSocket
wscat -c wss://api.blacksteep.com/ws/stream-generation

# Send message
> {"prompt": "test", "user_id": "test-user"}
```

**Using curl** (for HTTP upgrade test):
```bash
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  https://api.blacksteep.com/ws/stream-generation
```

### Getting Help

If you're still experiencing issues:

1. **Check CloudWatch Logs**:
   - Application logs: `/ecs/content-marketing-swarm-dev`
   - ALB access logs: `/aws/elasticloadbalancing/content-marketing-swarm-dev-alb`

2. **Review AWS Console**:
   - ECS service health
   - ALB target health
   - CloudWatch metrics

3. **Run diagnostic script**:
   ```bash
   python backend/diagnose_websocket.py
   ```

4. **Contact support** with:
   - Error messages from browser console
   - CloudWatch log excerpts
   - Diagnostic script output
   - Steps to reproduce the issue

## Performance Considerations

### Connection Limits

- **ALB**: Supports up to 1000 concurrent connections per target by default
- **ECS Task**: Estimated capacity of ~500 concurrent WebSocket connections per task
- **Scaling**: Service auto-scales based on CPU (>70%) and memory (>80%) utilization

### Message Throughput

- **Average message size**: ~1 KB
- **Messages per second per connection**: ~10
- **Total throughput per task**: ~5 MB/s (500 connections × 10 KB/s)

### Optimization Tips

1. **Implement client-side message batching** for high-frequency updates
2. **Use compression** for large messages (gzip)
3. **Limit connection duration** to reasonable timeframes
4. **Implement connection pooling** on the client side
5. **Monitor and scale** ECS tasks based on connection count

## Security Considerations

### Current Security Measures

1. **TLS Encryption**: All WebSocket connections use WSS (WebSocket Secure)
2. **CORS Validation**: Origin header checked against allowed origins
3. **ALB Security Groups**: Restrict inbound traffic to ports 80 and 443

### Future Enhancements

1. **Authentication**: Add JWT token validation for WebSocket connections
2. **Rate Limiting**: Implement per-user connection and message rate limits
3. **Message Validation**: Validate all incoming messages against schema
4. **Connection Limits**: Enforce maximum connections per user/IP

### Best Practices

1. **Always use WSS** (not WS) in production
2. **Validate all client messages** before processing
3. **Implement timeouts** for idle connections
4. **Log security events** (failed connections, invalid messages)
5. **Monitor for abuse** (excessive connections, large messages)

## Monitoring and Alerts

### Key Metrics to Monitor

1. **Active WebSocket Connections**: Track concurrent connection count
2. **Connection Success Rate**: Percentage of successful connections
3. **Message Throughput**: Messages per second
4. **Error Rate**: Failed connections and message errors
5. **Latency**: Time from message send to receive

### CloudWatch Alarms

Recommended alarms:

1. **High Error Rate**: > 10% of connections fail
2. **No Active Connections**: Zero connections for > 5 minutes
3. **Unhealthy Targets**: Any ECS task marked unhealthy
4. **High Latency**: P99 latency > 5 seconds

### Logging

All WebSocket events are logged to CloudWatch:

- Connection establishment
- Message send/receive
- Errors and exceptions
- Connection close

Log format:
```json
{
  "timestamp": "2025-11-25T11:30:00Z",
  "level": "INFO",
  "message": "WebSocket client connected",
  "client_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "remote_addr": "10.0.1.50"
}
```

## References

- [FastAPI WebSocket Documentation](https://fastapi.tiangolo.com/advanced/websockets/)
- [AWS ALB WebSocket Support](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [WebSocket Protocol RFC 6455](https://tools.ietf.org/html/rfc6455)
- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [CORS and WebSockets](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers)

## Changelog

- **2025-11-25**: Initial documentation created
  - WebSocket endpoint URL and message format
  - JavaScript connection examples
  - CORS configuration requirements
  - ALB configuration for WebSocket support
  - Comprehensive troubleshooting guide
