# Roadmap

This document captures Frost's strategic direction and planned features. Unlike GitHub Issues, which track concrete, actionable tasks ready for implementation, this roadmap communicates higher-level vision, features under consideration, and long-term ideas. Items listed here may not yet have detailed specifications or immediate timelines—they represent where the project aims to go rather than what is actively being worked on.

Use this roadmap to understand the project's direction and capabilities under consideration. When features become well-defined and ready for implementation, they will be tracked as GitHub Issues.

## DIMACS CNF Support

DIMACS CNF (Conjunctive Normal Form) is a standard format for representing boolean satisfiability problems in conjunctive normal form. Frost aims to provide comprehensive support for this format.

### Parsing

Parse DIMACS CNF files into internal representations:
- Read and validate CNF file headers (problem line, comments)
- Parse clause definitions with proper error handling
- Support for large files with efficient memory usage
- Validate logical consistency (variable numbering, clause structure)

### Emitting

Generate DIMACS CNF output from internal representations:
- Write well-formed CNF headers with accurate problem statistics
- Emit clauses in standard DIMACS format
- Optimize output for compactness and readability
- Support streaming output for large formulas

## DIMACS SAT Support

DIMACS SAT format represents boolean satisfiability problems in a different encoding than CNF. Providing SAT format support enables interoperability with a broader range of tools and workflows.

### Parsing

Parse DIMACS SAT files into internal representations:
- Read and validate SAT file headers
- Parse boolean formula expressions
- Handle various SAT format dialects and extensions
- Provide meaningful error messages for malformed input

### Emitting

Generate DIMACS SAT output from internal representations:
- Write SAT format headers and metadata
- Emit boolean formulas in SAT syntax
- Ensure output compatibility with standard SAT solvers
- Support different verbosity levels

## Format Conversion

Enable seamless conversion between different SAT problem representations, supporting multiple encoding strategies with different trade-offs.

### CNF to SAT Conversion

- Naive conversion: Direct translation preserving logical equivalence
- Optimization opportunities for simplified output

### SAT to CNF Conversion

- Naive conversion: Direct translation for simple cases
- Tseitin transformation: Introduce auxiliary variables to maintain polynomial size
- Preserve equisatisfiability while controlling formula size
- Support for different transformation strategies based on use case

## Documentation

Adopt the [Diátaxis framework](https://diataxis.fr/) for systematic, user-centric documentation covering different user needs and contexts.

### Tutorials

Learning-oriented guides for newcomers:
- Getting started with Frost as a library
- Building your first SAT problem converter
- Understanding CNF and SAT formats
- Common use cases and patterns

### How-To Guides

Task-oriented guides for specific problems:
- Converting between specific formats
- Integrating Frost into build systems
- Performance optimization techniques
- Error handling best practices

### Explanations

Understanding-oriented deep dives:
- CNF vs SAT format trade-offs
- Tseitin transformation explained
- Internal architecture and design decisions
- Format specification details

## Future Considerations

### Preprocessing

Preprocessing can simplify SAT problems before solving, improving solver performance:
- Variable elimination techniques
- Clause subsumption and strengthening
- Pure literal elimination
- Unit propagation
- Failed literal probing

These features require careful design to maintain correctness while providing meaningful simplification. They may be explored once core format support is stable.
