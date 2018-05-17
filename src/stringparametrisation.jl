using Dierckx

function parametrise!{T}(t::Vector{T}, x::Vector{T}, ds::T; parametrisation=linspace(0.,1.,length(x)))

   param = [0; [sum(ds[1:i]) for i in 1:length(ds)]]
   param /= param[end]; param[end] = 1.

   S = [Spline1D(param, [x[i][j] for i=1:length(x)], w = ones(length(x)), k = 3, bc = "error") for j=1:length(x[1])]

   xref = [[Sj(s) for s in parametrisation] for Sj in S ]
   tref = [[derivative(Sj, s) for s in parametrisation] for Sj in S]

   x_ = cat(2, xref...)
   t_ = cat(2, tref...)
   [x[i] = x_[i,:] for i=1:length(x)]
   [t[i] = t_[i,:] for i=1:length(x)]
   return x, t
end


function refine!(param, refine_points, t)
   N = length(t)
   for n = 2:N-1
      cosine = dot(t[n-1], t[n+1]) / (norm(t[n-1]) * norm(t[n+1]))
      if ( cosine < 0 )
         n1 = n-1; n2 = n+1; k = refine_points
         # number of nodes moved from [0., param[n1]) to [param[n1], param[n2]]
         k1 = floor(param[n1] * k)
         # number of nodes moved from (param[n2], 1.] to [param[n1], param[n2]]
         k2 = floor((param[end] - param[n2-1]) * k)
         # update the number refine points to be consistend with integer partitioning of [0., param[n1]) and (param[n2], 1.]
         k = k1 + k2
         # new parametrisation of [0., param[n1])
         s1 = (n1 - k1 == 1) ? [.0] : collect(linspace(.0, 1., n1 - k1 )) * param[n1]
         # new parametrisation of [param[n1], param[n2]]
         s2 = collect(param[n1] + linspace(.0, 1., k + 3 ) * (param[n2] - param[n1]))
         # new parametrisation of (param[n2], 1.]
         s3 = (N - n2 - k2 + 1 == 1) ? [1.] : collect(param[n2] + linspace(.0, 1., N - n2 - k2 + 1 ) * (1 - param[n2]))
         # update parametrisation
         param[:] = [s1;  s2[2:end-1]; s3][:]
      else
         param[:] = collect(linspace(0., 1., length(t)))[:]
      end
   end
   return param
end

function redistribute{T}(xref::Vector{Float64}, x::Vector{T}, precon_scheme)
   @unpack precon, precon_prep!, = precon_scheme

   x = set_ref!(x, xref)
   t = copy(x)

   precon = precon_prep!(precon, x)
   Np = length(precon);
   function P(i) return precon[mod(i-1,Np)+1, 1]; end
   function P(i, j) return precon[mod(i-1,Np)+1, mod(j-1,Np)+1]; end

   ds = [dist(precon_scheme, P, x, i) for i=1:length(x)-1]
   parametrise!(t, x, ds)

   return ref(x)
end
