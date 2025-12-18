"""
Smoke test - quick sanity check that the package loads and basic functionality works
Run this before running the full test suite
"""

using HierarchicalMineralExploration
using Turing
using Distributions
using AbstractGPs
using POMDPs
using DataStructures
using Random

println("Testing package import...")
@assert HierarchicalMineralExploration isa Module
println("✓ Package imports successfully")

println("\nTesting basic types...")
K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
N = 32

# Test domains
t₀ = ThicknessBackground(1.0, K)
@assert t₀.μ == 1.0
println("✓ ThicknessBackground created")

γ₀ = GradeBackground(0.0, K)
@assert γ₀.μ == 0.0
println("✓ GradeBackground created")

graben = GrabenDistribution(; N=N, μ=9.5)
@assert graben.N == N
println("✓ GrabenDistribution created")

geochem = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)
@assert geochem.N == N
println("✓ GeochemicalDomainDistribution created")

# Test domain drawing
println("\nTesting domain generation...")
graben_domain = draw_graben(N, 16.0, 8.0, 16.0, 8.0)
@assert size(graben_domain) == (N, N)
println("✓ Graben drawn successfully")

geochem_domain = draw_geochemical_domain(N, (16.0, 16.0), fill(5.0, 10))
@assert size(geochem_domain) == (N, N)
println("✓ Geochemical domain drawn successfully")

# Test hypothesis
println("\nTesting hypothesis creation...")
σₜ = 0.001
σᵧ = 0.001
h = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
@assert h.N == N
println("✓ Hypothesis created")

# Test turing model
println("\nTesting Turing model...")
m_type = turing_model(h)
@assert m_type == one_graben_one_geochem
println("✓ Turing model type selected correctly")

m = m_type(Dict(), h, true)
result = m()
@assert haskey(result, :thickness)
@assert haskey(result, :grade)
@assert size(result.thickness) == (N, N)
println("✓ State sampled from Turing model")

# Test POMDP state
println("\nTesting POMDP components...")
s = HierarchicalMinExState(result.thickness, result.grade)
@assert s.thickness isa Matrix{Float32}
println("✓ HierarchicalMinExState created")

# Test POMDP
pomdp = HierarchicalMinExPOMDP()
@assert pomdp.grid_dims == (32, 32)
println("✓ HierarchicalMinExPOMDP created")

# Test basic POMDP functions
@assert :abandon in actions(pomdp)
@assert discount(pomdp) == 0.999
@assert isterminal(pomdp, :terminal)
println("✓ POMDP functions work")

# Test gen
Random.seed!(42)
gen_result = gen(pomdp, s, (3, 3))
@assert gen_result.sp == s
@assert gen_result.o isa Tuple
println("✓ POMDP gen function works")

# Test max entropy hypothesis
println("\nTesting MaxEntropyHypothesis...")
meh = MaxEntropyHypothesis(Normal(8, 8), Normal(8, 8))
lp = logprob(meh, Dict())
@assert lp == 0.0
println("✓ MaxEntropyHypothesis works")

println("\n" * "="^50)
println("ALL SMOKE TESTS PASSED! ✓")
println("="^50)
println("\nThe package is ready to use. You can now run the full test suite with:")
println("  julia --project=. -e 'using Pkg; Pkg.test()'")
