using Test
using HierarchicalMineralExploration
using Turing
using Distributions
using AbstractGPs
using POMDPs
using ParticleFilters
using DataStructures
using Random

@testset "HierarchicalMineralExploration.jl" begin

    @testset "Domain Tests" begin
        @testset "GradeBackground" begin
            K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
            gb = GradeBackground(0.0, K)
            @test gb.μ == 0.0
            @test gb.kernel == K
        end

        @testset "ThicknessBackground" begin
            K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
            tb = ThicknessBackground(1.0, K)
            @test tb.μ == 1.0
            @test tb.kernel == K
        end

        @testset "GeochemicalDomainDistribution" begin
            K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
            N = 32
            gd = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)
            @test gd.N == N
            @test gd.μ == 7.5
            @test gd.kernel == K

            # Test logpdf
            cx, cy = 16.0, 16.0
            rs = fill(5.0, 10)
            lp = logpdf(gd, cx, cy, rs...)
            @test lp isa Float64
            @test isfinite(lp)
        end

        @testset "draw_geochemical_domain" begin
            N = 32
            center = (16.0, 16.0)
            rs = fill(5.0, 10)
            domain = draw_geochemical_domain(N, center, rs)
            @test size(domain) == (N, N)
            @test all(x -> x in [0.0, 1.0], domain)
        end

        @testset "GrabenDistribution" begin
            N = 32
            gd = GrabenDistribution(; N=N, μ=9.5)
            @test gd.N == N
            @test gd.μ == 9.5

            # Test logpdf
            lt, lw, rt, rw = 16.0, 8.0, 16.0, 8.0
            lp = logpdf(gd, lt, lw, rt, rw)
            @test lp isa Float64
            @test isfinite(lp)
        end

        @testset "draw_graben" begin
            N = 32
            graben = draw_graben(N, 16.0, 8.0, 16.0, 8.0)
            @test size(graben) == (N, N)
            @test all(x -> x in [0.0, 1.0], graben)
        end
    end

    @testset "Hypothesis Tests" begin
        K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
        N = 32
        t₀ = ThicknessBackground(1.0, K)
        σₜ = 0.001
        γ₀ = GradeBackground(0.0, K)
        σᵧ = 0.001

        graben = GrabenDistribution(; N=N, μ=9.5)
        geochem = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)

        @testset "Hypothesis construction" begin
            h = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
            @test h.N == N
            @test h.σ_thickness == σₜ
            @test h.σ_grade == σᵧ
            @test length(h.grabens) == 1
            @test length(h.geochem_domains) == 1
        end

        @testset "turing_model selection" begin
            h11 = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
            @test turing_model(h11) == one_graben_one_geochem

            h12 = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem, geochem])
            @test turing_model(h12) == one_graben_two_geochem

            h21 = Hypothesis(N, t₀, σₜ, [graben, graben], γ₀, σᵧ, [geochem])
            @test turing_model(h21) == two_graben_one_geochem

            h22 = Hypothesis(N, t₀, σₜ, [graben, graben], γ₀, σᵧ, [geochem, geochem])
            @test turing_model(h22) == two_graben_two_geochem
        end

        @testset "default_alg" begin
            h = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
            alg = default_alg(h)
            @test alg isa Turing.Inference.InferenceAlgorithm
        end

        @testset "MaxEntropyHypothesis" begin
            meh = MaxEntropyHypothesis(Normal(8, 8), Normal(8, 8))
            @test meh.thickness_dist isa Normal
            @test meh.grade_dist isa Normal

            # Test logprob with empty observations
            lp = logprob(meh, Dict())
            @test lp == 0.0

            # Test logprob with observations
            obs = Dict([1, 1] => (thickness=5.0, grade=3.0))
            lp = logprob(meh, obs)
            @test lp isa Float64
            @test isfinite(lp)
        end
    end

    @testset "POMDP Tests" begin
        @testset "HierarchicalMinExState" begin
            s = HierarchicalMinExState(rand(Float32, 32, 32), rand(Float32, 32, 32))
            @test s.thickness isa Matrix{Float32}
            @test s.grade isa Matrix{Float32}
            @test size(s.thickness) == (32, 32)
            @test size(s.grade) == (32, 32)

            # Test hash and equality
            s2 = HierarchicalMinExState(s.thickness, s.grade)
            @test hash(s) == hash(s2)
            @test s == s2
        end

        @testset "HierarchicalMinExPOMDP" begin
            pomdp = HierarchicalMinExPOMDP()
            @test pomdp.grid_dims == (32, 32)
            @test discount(pomdp) == 0.999
            @test length(actions(pomdp)) > 0
            @test :abandon in actions(pomdp)
            @test :mine in actions(pomdp)
            @test isterminal(pomdp, :terminal)
        end

        @testset "calc_massive and extraction_reward" begin
            pomdp = HierarchicalMinExPOMDP(; grade_threshold=6.0)
            s = HierarchicalMinExState(ones(Float32, 32, 32) .* 5, ones(Float32, 32, 32) .* 8)
            massive = calc_massive(pomdp, s)
            @test massive isa Float64
            @test massive > 0

            reward_val = extraction_reward(pomdp, s)
            @test reward_val isa Float64
        end

        @testset "reward function" begin
            pomdp = HierarchicalMinExPOMDP()
            s = HierarchicalMinExState(rand(Float32, 32, 32), rand(Float32, 32, 32))

            # Test abandon
            @test reward(pomdp, s, :abandon) == 0

            # Test terminal
            @test reward(pomdp, :terminal, :abandon) == 0

            # Test drill
            @test reward(pomdp, s, (3, 3)) == -pomdp.drill_cost

            # Test mine
            r = reward(pomdp, s, :mine)
            @test r isa Float64
        end

        @testset "observation function" begin
            pomdp = HierarchicalMinExPOMDP()
            s = HierarchicalMinExState(ones(Float32, 32, 32) .* 5, ones(Float32, 32, 32) .* 8)

            # Test drill observation
            obs_dist = observation(pomdp, (3, 3), s)
            @test obs_dist isa Distribution

            # Test terminal observation
            obs_dist = observation(pomdp, :abandon, s)
            @test obs_dist isa POMDPTools.SparseCat
        end

        @testset "gen function" begin
            Random.seed!(42)
            pomdp = HierarchicalMinExPOMDP()
            s = HierarchicalMinExState(ones(Float32, 32, 32) .* 5, ones(Float32, 32, 32) .* 8)

            # Test drill action
            result = gen(pomdp, s, (3, 3))
            @test result.sp == s
            @test result.o isa Tuple
            @test result.r == -pomdp.drill_cost

            # Test terminal action
            result = gen(pomdp, s, :abandon)
            @test result.sp == :terminal
            @test result.r == 0
        end
    end

    @testset "Belief Tests" begin
        K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
        N = 32
        t₀ = ThicknessBackground(1.0, K)
        σₜ = 0.001
        γ₀ = GradeBackground(0.0, K)
        σᵧ = 0.001

        graben = GrabenDistribution(; N=N, μ=9.5)
        geochem = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)

        @testset "MCMCUpdater construction" begin
            hypotheses = OrderedDict(1 => Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem]))
            updater = MCMCUpdater(100, hypotheses)
            @test updater.Nsamples == 100
            @test length(updater.hypotheses) == 1
            @test isempty(updater.observations)
        end

        @testset "MultiHypothesisBelief" begin
            particles_vec = [HierarchicalMinExState(rand(Float32, 32, 32), rand(Float32, 32, 32)) for _ in 1:10]
            pc = ParticleCollection(particles_vec)
            hypotheses_vec = fill(1, 10)
            belief = MultiHypothesisBelief(pc, hypotheses_vec)
            @test length(particles(belief)) == 10
            @test belief.hypotheses == hypotheses_vec
        end
    end

    @testset "Turing Model Tests" begin
        K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
        N = 32
        t₀ = ThicknessBackground(1.0, K)
        σₜ = 0.001
        γ₀ = GradeBackground(0.0, K)
        σᵧ = 0.001

        graben = GrabenDistribution(; N=N, μ=9.5)
        geochem = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)

        @testset "one_graben_one_geochem" begin
            h = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
            m = one_graben_one_geochem(Dict(), h, true)

            # Sample from the model
            result = m()
            @test result isa NamedTuple
            @test haskey(result, :structural)
            @test haskey(result, :geochemdomain)
            @test haskey(result, :thickness)
            @test haskey(result, :grade)
            @test size(result.thickness) == (N, N)
            @test size(result.grade) == (N, N)
        end

        @testset "getobs utility" begin
            obs = Dict([1, 1] => (thickness=5.0, grade=3.0), [2, 2] => (thickness=6.0, grade=4.0))
            pts, values = getobs(obs, :thickness)
            @test length(pts) == 2
            @test length(values) == 2
            @test all(v -> v isa Float64, values)

            # Test with check function
            pts, values = getobs(obs, :grade, x -> x[1] == 1)
            @test length(pts) == 1
            @test length(values) == 1
        end
    end

    @testset "Integration Tests" begin
        @testset "Sample from hypothesis and run POMDP" begin
            K = 0.1 * Matern52Kernel() ∘ ScaleTransform(1.0 / 3.0)
            N = 32
            t₀ = ThicknessBackground(1.0, K)
            σₜ = 0.001
            γ₀ = GradeBackground(0.0, K)
            σᵧ = 0.001

            graben = GrabenDistribution(; N=N, μ=9.5)
            geochem = GeochemicalDomainDistribution(; N=N, μ=7.5, kernel=K)

            h = Hypothesis(N, t₀, σₜ, [graben], γ₀, σᵧ, [geochem])
            m = turing_model(h)(Dict(), h, true)

            # Sample a state
            result = m()
            s = HierarchicalMinExState(result.thickness, result.grade)

            # Create POMDP
            pomdp = HierarchicalMinExPOMDP()

            # Take an action
            a = (3, 3)
            gen_result = gen(pomdp, s, a)

            @test gen_result.sp == s
            @test gen_result.o isa Tuple
            @test gen_result.r == -pomdp.drill_cost
        end
    end
end
