

export BBDimer

# TODO: change maxnit to maxn_dE

"""
`BBDimer`: dimer method with Barzilai-Borwein step-size + an Armijo
type stability check.

### Parameters:
* `a0_trans` : initial translation step
* `a0_rot` : initial rotation step
* `ls` : linesearch

### Shared Parameters
* `tol_trans` : translation residual tolerance
* `tol_rot` : rotation residual tolerance
* `maxnumdE` : maximum number of dE evalluations
* `len` : dimer-length (i.e. distance of the two walkers)
* `precon` : preconditioner
* `precon_prep!` : update function for preconditioner
* `verbose` : how much information to print (0: none, 1:end of iteration, 2:each iteration)
* `precon_rot` : true/false whether to precondition the rotation step

## References

The method combines ideas from

[ZDZ] Optimization-based Shrinking Dimer Method for Finding Transition States
SIAM J. Sci. Comput., 38(1), A528–A544
Lei Zhang, Qiang Du, and Zhenzhen Zheng
DOI:10.1137/140972676

and

[GOP] A dimer-type saddle search algorithm with preconditioning and linesearch
Math. Comp. 85, 2016
N. Gould and C. Ortner and D. Packwood
http://arxiv.org/abs/1407.2817
"""
@with_kw type BBDimer
   a0_trans::Float64
   a0_rot::Float64
   ls = StaticLineSearch()
   # ------ shared parameters ------
   tol_trans::Float64 = 1e-5
   tol_rot::Float64 = 1e-2
   maxnumdE::Int = 2000
   len::Float64 = 1e-3
   precon = I
   precon_prep! = (P, x) -> P
   verbose::Int = 2
   precon_rot::Bool = false
   id::AbstractString = "BBDimer"
end


function run!{T}(method::BBDimer, E, dE, x0::Vector{T}, v0::Vector{T})

   # read all the parameters
   @unpack a0_trans, a0_rot, tol_trans, tol_rot, maxnumdE, len,
            precon_prep!, verbose, precon_rot, ls = method
   P=method.precon
   # initialise variables
   x, v = copy(x0), copy(v0)
   β, γ = -1.0, -1.0   # this tells the loop that they haven't been initialised
   numdE, numE = 0, 0
   log = IterationLog()
   p_trans_old = zeros(length(x0))
   p_rot_old = zeros(length(x0))
   # and just start looping
   if verbose >= 2
      @printf(" nit |  |∇E|_∞    |∇R|_∞        λ         β         γ \n")
      @printf("-----|------------------------------------------------\n")
   end
   nit = 0
   while true
      nit += 1

      @assert !any(isnan(v))
      @assert !any(isnan(x))

      # normalise v
      P = precon_prep!(P, x)
      v /= sqrt(dot(v, P, v))
      # evaluate gradients, and more stuff
      dEm = dE(x - len/2 * v)
      dEp = dE(x + len/2 * v)
      numdE += 2
      Hv = (dEp - dEm) / len
      dE0 = 0.5 * (dEp + dEm)
      # translation and rotation residual, store history
      res_trans = vecnorm(dE0, Inf)
      λ = dot(v, Hv)
      p_rot = - Hv + λ * (P * v)
      res_rot = vecnorm(p_rot, Inf)
      push!(log, numE, numdE, res_trans, res_rot)
      if verbose >= 2
         @printf("%4d | %1.2e  %1.2e  %1.2e  %1.2e  %1.2e \n",
               nit, res_trans, res_rot, λ, β, γ)
      end

      # check whether to terminate
      if res_trans <= tol_trans && res_rot <= tol_rot
         if verbose >= 1
            println("BBDimer terminates succesfully after $(nit) iterations")
         end
         return x, v, log
      end
      if numdE > maxnumdE
         if verbose >= 1
            println("BBDimer terminates unsuccesfully due to numdE >= $(maxnumdE)")
         end
         return x, v, log
      end

      # compute the two "search" directions
      p_trans = - P \ dE0 + 2.0 * dot(v, dE0) * v
      if precon_rot
         p_rot = P \ p_rot
      end

      # initial step-sizes guess
      if nit == 1     # first iteration
         β = a0_trans
         γ = a0_rot
      else             # subsequent iterations: BB step
         # Δx, Δv has already been computed (see end of loop)
         Δg = p_trans - p_trans_old
         Δd = p_rot - p_rot_old
         β = abs( dot(Δx, P, Δg) / dot(Δg, P, Δg) )
         γ = abs( dot(Δv, P, Δd) / dot(Δd, P, Δd) )
      end

      # perform linesearch on the translation step
      F_trans = xx -> localmerit(xx, x, v, len, dE0, λ, E)
      β, numE_ls, _ = linesearch!(ls, F_trans, F_trans(x), - dot(p_trans, P, p_trans),
                                    x, p_trans, β)
      numE += numE_ls

      # perform line-search on rotation step
      E0 = E(x);  numE += 1
      F_rot = vv -> rayleigh(vv, x, len, E0, E, P)
      γ, numE_ls, _ = linesearch!(ls, F_rot, F_rot(v), -dot(p_rot, P, p_rot),
                                    v, p_rot, γ)
      numE += numE_ls

      # translation step
      x += β * p_trans
      # rotation step
      v += γ * p_rot

      # remember the change in x and v, also remember the old p_trans and p_rot
      Δx = β * p_trans
      Δv = γ * p_rot
      copy!(p_trans_old, p_trans)
      copy!(p_rot_old, p_rot)
   end
   error("why am I here?")
end