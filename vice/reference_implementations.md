# VICE Debugger Reference Implementations

This document summarizes lessons learned from existing VICE debugger implementations.

## Examined Projects

| Project       | Language   | GitHub                                                                 | Key Lesson                         |
|---------------|------------|------------------------------------------------------------------------|------------------------------------|
| VS64          | JavaScript | [rolandshacks/vs64](https://github.com/rolandshacks/vs64)              | Reference VS Code debugger         |
| cc65-debugger | TypeScript | [empathicqubit/vscode-cc65-debugger](https://github.com/empathicqubit/vscode-cc65-debugger) | Well-structured protocol handling |
| pyvicemon     | Python     | [Galfodo/pyvicemon](https://github.com/Galfodo/pyvicemon)              | Clean protocol implementation      |
| IceBro Lite   | C++        | [Sakrac/IceBroLite](https://github.com/Sakrac/IceBroLite)              | Standalone GUI debugger            |

## VS64 - Critical Lessons

### VICE Startup Sequence

VS64 starts VICE with the following command line:

```bash
x64sc +remotemonitor -binarymonitor -binarymonitoraddress ip4://127.0.0.1:6502 -autostartprgmode 1
```

**Critical options:**
- `+remotemonitor` - DISABLE text monitor (binary only!)
- `-autostartprgmode 1` - PRG injection into RAM (not autostart!)

### Program Loading Sequence

```javascript
// VS64 debug_vice.js - loadProgram() method
async loadProgram(filename) {
    await this.init();
    await this.cmdReset();                    // 1. Send RESET!
    await this.cmdAutostart(filename, true);  // 2. Binary autostart
}
```

**CRITICAL:** The RESET command is sent BEFORE autostart!

### Debug Session Initialization

```
VS64 Initialization Sequence:
─────────────────────────────────────────────────────────────────
1. VICE spawn (empty, without program!)
2. Socket connect (retry loop at 250ms interval)
3. cmdRegistersAvailable() - get register list
4. cmdBanksAvailable() - get memory banks
5. loadProgram():
   a. cmdReset()
   b. cmdAutostart(filename)
6. setBreakpoints() - set breakpoints
7. start() → cmdExit() - start execution
─────────────────────────────────────────────────────────────────
```

### Breakpoint Handling

```javascript
// setBreakpoints() method
async setBreakpoints(breakpoints) {
    // 1. Get existing checkpoints
    const existing = await this.cmdCheckpointList();

    // 2. Delete unnecessary checkpoints
    for (const cp of existing) {
        if (!breakpoints.find(bp => bp.address === cp.address)) {
            await this.cmdCheckpointDelete(cp.id);
        }
    }

    // 3. Create new checkpoints
    for (const bp of breakpoints) {
        if (!existing.find(cp => cp.address === bp.address)) {
            await this.cmdCheckpointSet(bp.address, bp.address, true, true, 0x04);
        }
    }
}
```

### Stopped Event Handling

```javascript
// RESPONSE_STOPPED (0x62) event processing
onStoppedEvent(response) {
    const pc = this.registers.pc;

    // Step mode: check if we're at a source line
    if (this.stepMode) {
        const info = this.debugInfo.getAddressInfo(pc);
        if (!info || !info.line) {
            // Intermediate code - continue automatically
            this.cmdExit();
            return;
        }
    }

    // Breakpoint: which checkpoint?
    const checkpoint = this.findCheckpointAtAddress(pc);

    // Send DAP StoppedEvent
    this.sendEvent('stopped', {
        reason: checkpoint ? 'breakpoint' : 'step',
        threadId: 1
    });
}
```

## cc65-debugger - Protocol Handling

### binary-dto.ts - Message Types

```typescript
// Command types
export enum CommandType {
    memoryGet = 0x01,
    memorySet = 0x02,
    checkpointSet = 0x12,
    checkpointDelete = 0x13,
    checkpointList = 0x14,
    checkpointToggle = 0x15,
    registersGet = 0x31,
    registersSet = 0x32,
    registersAvailable = 0x83,
    advanceInstructions = 0x71,
    executeUntilReturn = 0x73,
    ping = 0x81,
    exit = 0xbb,
    quit = 0xaa,
    reset = 0xcc,
    autostart = 0xdd,
}

// Response types
export enum ResponseType {
    stopped = 0x62,     // Emulator stopped (breakpoint, step)
    resumed = 0x63,     // Emulator resumed
    jam = 0x61,         // CPU JAM (illegal opcode)
    checkpointInfo = 0x11,  // Breakpoint hit info
}
```

### Asynchronous Response Handling

```typescript
// Request ID based response handling
class BinaryProtocol {
    private pendingRequests: Map<number, Promise>;
    private requestId: number = 0;

    async sendCommand(type: CommandType, body: Buffer): Promise<Response> {
        const id = this.requestId++;
        const promise = new Promise((resolve) => {
            this.pendingRequests.set(id, resolve);
        });

        this.socket.write(this.buildPacket(type, id, body));
        return promise;
    }

    onData(data: Buffer) {
        const response = this.parseResponse(data);

        // Event response (no request ID)
        if (response.type === ResponseType.stopped) {
            this.emit('stopped', response);
            return;
        }

        // Request response
        const resolver = this.pendingRequests.get(response.requestId);
        if (resolver) {
            resolver(response);
            this.pendingRequests.delete(response.requestId);
        }
    }
}
```

## pyvicemon - Python Reference

### Protocol Header Format

```python
# Command header (11 bytes)
CMD_HEADER = [
    ('stx', uint8),           # 0x02
    ('api_version', uint8),   # 0x02
    ('body_size', uint32),    # Little-endian
    ('request_id', uint32),   # Little-endian
    ('command', uint8)
]

# Response header (12 bytes)
RESPONSE_HEADER = [
    ('stx', uint8),           # 0x02
    ('api_version', uint8),   # 0x02
    ('body_size', uint32),
    ('response_type', uint8),
    ('error_code', uint8),    # 0x00 = OK
    ('request_id', uint32)
]
```

### Event Polling

```python
def wait_for_debugger_event(timeout=1.0):
    """Wait for VICE event (breakpoint, JAM, etc.)"""
    sock.settimeout(timeout)

    while True:
        try:
            data = sock.recv(4096)
            response = parse_response(data)

            if response.type == MON_RESPONSE_STOPPED:
                return response
            elif response.type == MON_RESPONSE_CHECKPOINT_INFO:
                # Breakpoint hit
                return response

        except socket.timeout:
            return None  # No event
```

## Comparison: What Was Wrong with PyCo Approach

### Original PyCo Sequence (WRONG)

```
1. Start VICE: x64sc -binarymonitor -autostart-delay 3 program.prg
2. Socket connect
3. Set breakpoint
4. cmdExit() (continue)
```

**Problems:**
1. PRG on command line → VICE immediately starts autostart
2. `-autostart-delay` delays it, but VICE goes to "stopped" state on connect
3. Program has already passed the entry point by the time breakpoint is set

### Correct Sequence (based on VS64)

```
1. Start VICE: x64sc -binarymonitor (WITHOUT PROGRAM!)
2. Socket connect
3. cmdReset()
4. cmdAutostart(program.prg, run=true)  # Binary protocol autostart
5. Set breakpoint
6. cmdExit() (continue)
```

**Why this works:**
1. VICE starts in empty state
2. Reset ensures clean state
3. Binary autostart loads program BUT DOESN'T START IT (when run=false)
4. Breakpoints can be set
5. Exit command starts the program

## Implementation Plan for PyCo

### 1. ViceManager Modifications

```typescript
// vice-manager.ts

async debugProgram(prgFile: string, entryPointAddress?: number): Promise<void> {
    // 1. Start VICE in EMPTY state
    await this.startViceEmpty();

    // 2. Wait for connection
    await this.waitForConnection();

    // 3. Send reset (clean state)
    await this.viceClient.reset();

    // 4. Load program with binary autostart
    await this.viceClient.autostart(prgFile, false);  // run=false!

    // 5. Set entry breakpoint (if any)
    if (entryPointAddress !== undefined) {
        await this.viceClient.checkpointSet(entryPointAddress, ...);
    }

    // 6. Start execution
    await this.viceClient.continue();
}

private async startViceEmpty(): Promise<void> {
    const args = [
        '-binarymonitor',
        '-binarymonitoraddress', `${this.host}:${this.port}`,
        '+remotemonitor',      // Disable text monitor
        '-autostartprgmode', '1',  // RAM inject mode
    ];
    // Do NOT specify the PRG file!
    this.viceProcess = spawn(this.vicePath, args);
}
```

### 2. ViceClient Additions

```typescript
// vice-client.ts

async reset(): Promise<void> {
    // 0xCC - Reset command
    const body = Buffer.from([0x00]);  // Soft reset
    await this.sendCommand(CommandType.RESET, body);
}

async autostart(filename: string, run: boolean = true): Promise<void> {
    // 0xDD - Autostart command
    const body = Buffer.alloc(3 + filename.length);
    body.writeUInt8(run ? 0x01 : 0x00, 0);  // Run flag
    body.writeUInt16LE(0, 1);                // File index
    Buffer.from(filename).copy(body, 3);     // Filename

    await this.sendCommand(CommandType.AUTOSTART, body);
}
```

### 3. Event Handling Improvements

```typescript
// debug-session.ts

private setupViceEventHandlers(): void {
    this.viceClient.on('stopped', (data: StoppedEventData) => {
        // Get PC from registers
        const registers = await this.viceClient.getRegisters();

        // Find source location
        const source = this.sourceMapper.getSourceLocation(registers.pc);

        // Send DAP StoppedEvent
        this.sendEvent(new StoppedEvent('breakpoint', 1));
    });
}
```

## Debugging Tips

### Monitoring VICE Output

```bash
# Redirect VICE stdout/stderr
x64sc -binarymonitor 2>&1 | tee vice.log
```

### Binary Protocol Debugging

```typescript
// Log all sent/received messages
socket.on('data', (data) => {
    console.log('RECV:', data.toString('hex'));
});

const originalWrite = socket.write.bind(socket);
socket.write = (data) => {
    console.log('SEND:', data.toString('hex'));
    return originalWrite(data);
};
```

### Common Errors

| Error                   | Cause                    | Solution                      |
|-------------------------|--------------------------|-------------------------------|
| CMD_FAILURE (0x8f) autostart | VICE already running/loading | Send reset first           |
| Breakpoint not hit      | PC already passed        | Reset + autostart order       |
| Timeout                 | VICE slow startup        | Increase retry loop           |
| Disconnected            | VICE crash/quit          | Improve error handling        |

## Sources

- [VICE Binary Monitor Protocol](https://vice-emu.sourceforge.io/vice_13.html)
- [VS Code Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)
- [VS64 Source Code](https://github.com/rolandshacks/vs64/tree/master/src/debugger)
- [cc65-debugger Source Code](https://github.com/empathicqubit/vscode-cc65-debugger/tree/master/src/dbg)
