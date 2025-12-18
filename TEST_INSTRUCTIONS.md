# Testing Instructions for HierarchicalMineralExploration.jl

## Prerequisites

You need Julia installed (version 1.9 or higher recommended). Download from [julialang.org](https://julialang.org/downloads/).

## Installation and Setup

1. Navigate to the project directory:
   ```bash
   cd HierarchicalMineralExploration.jl
   ```

2. Install dependencies:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

## Running Tests

### Quick Smoke Test (Recommended First)

Run a quick smoke test to verify basic functionality:

```bash
julia --project=. test/smoke_test.jl
```

This will:
- Test that the package loads correctly
- Verify all basic types can be created
- Test domain generation functions
- Sample from Turing models
- Run basic POMDP operations

Expected output: All tests should pass with ✓ marks.

### Full Test Suite

Run the comprehensive test suite:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or directly:

```bash
julia --project=. test/runtests.jl
```

The full test suite covers:
- Domain functionality (GradeBackground, ThicknessBackground, etc.)
- Hypothesis creation and model selection
- POMDP state and problem definition
- Belief updater functionality
- Turing model sampling
- Integration tests

### Running Examples

The `examples/` directory contains several demonstration scripts:

1. **Basic POMDP example** (requires additional setup):
   ```bash
   julia --project=examples examples/pomdp_example.jl
   ```

2. **Belief updater demo**:
   ```bash
   julia --project=examples examples/belief_updater_demo.jl
   ```

3. **Bridge sampling demo**:
   ```bash
   julia --project=examples examples/bridge_sampling_demo.jl
   ```

Note: Some examples may require additional packages or create output directories.

## Expected Test Results

All tests should pass. If any tests fail, check:

1. **Julia version**: Ensure you're using Julia 1.9+
2. **Dependencies**: Run `Pkg.instantiate()` again
3. **Package versions**: Check `Project.toml` for compatibility

## Troubleshooting

### "Package not found" errors
Run: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`

### Turing.jl compilation errors
The first run may take several minutes as Turing.jl compiles. Be patient.

### Memory issues
Some examples run MCMC sampling which can be memory-intensive. Reduce `Nsamples` if needed.

## Code Review Summary

### ✓ No Syntax Errors Found
All source files were reviewed and no syntax errors were detected:
- `src/HierarchicalMineralExploration.jl` - Main module (✓)
- `src/domains.jl` - Domain definitions (✓)
- `src/hypotheses.jl` - Hypothesis and Turing models (✓)
- `src/pomdp.jl` - POMDP problem definition (✓)
- `src/beliefs.jl` - Belief updaters (✓)
- `src/visualization.jl` - Plotting functions (✓)

### Code Quality Notes

1. **Well-structured**: Clean separation of concerns across modules
2. **Properly documented**: Good use of docstrings
3. **Type-safe**: Uses Julia's type system effectively
4. **POMDP compliant**: Implements POMDPs.jl interface correctly
5. **Bayesian modeling**: Proper use of Turing.jl for probabilistic programming

### Potential Issues to Watch

1. **Performance**: MCMC sampling can be slow for large `Nsamples`
2. **Memory**: Particle filtering with many particles may use significant RAM
3. **Visualization**: Some plotting functions assume specific data structures

## Next Steps

After successful testing:
1. Review example outputs in the `examples/` directory
2. Customize hypothesis configurations in `examples/setup.jl`
3. Run experiments with different parameters
4. Visualize results using the plotting functions

## Contact

For issues or questions, refer to the repository maintainers.
