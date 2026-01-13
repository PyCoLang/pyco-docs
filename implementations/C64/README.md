# PyCo C64 Implementation

This directory contains documentation for the **Commodore 64 (6502)** backend of the PyCo compiler.

## Documentation

### Compiler Reference

Complete reference for the C64 backend:

- [c64_compiler_reference_en.md](c64_compiler_reference_en.md)

Covers: memory layout, zero page usage, decorators, IRQ handling, runtime behavior.

### Code Generator Internals

Internal design documentation for compiler developers:

- [codegen_internals_en.md](codegen_internals_en.md)

Covers: calling conventions, stack frame layout, expression evaluation, name mangling.

### Module System

Dynamic module loading for memory-efficient programs:

- [module_system_en.md](module_system_en.md)

Covers: .PYCOM file format, marker-byte relocation, static vs dynamic imports.

### VICE Debugger Integration

Documentation for debugger development:

- [vice/](vice/)

Covers: binary monitor protocol, debug adapter design, reference implementations.
