tol = 2e-2
maxint = 2000

@testset "String with ODE" begin

preconI = SaddleSearch.localPrecon(precon = [I], precon_prep! = (P, x) -> P,
precon_cond = true)

heading1("TEST: String type methods with ode12r solver")

heading2("Muller potential")
V = MullerPotential()
x0, x1 = ic_path(V, :near)
E, dE = objective(V)
precon = x-> hessianprecond(V, x)

N = 15
x = [(1-s)*x0 + s*x1 for s in linspace(.0, 1., N)]
t = [((x1-x0)/norm(x1-x0)) for s in linspace(.0, 1., N)]

path = StringMethod(0.0009, tol, maxint, I, (P, x) -> P, 1, false)
PATHx, PATHlog = run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

path = ODEStringMethod(SaddleSearch.ODE12r(atol=1e-2, rtol=1e-2), preconI,
serial(), tol, maxint, 1)
PATHx, PATHlog, _ = SaddleSearch.run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

heading2("Double well potential")
c = 16.0
V = DoubleWell(diagm([.5, c*c*(0.02^(c-1)), c]))
x0, x1 = ic_path(V, :near)
E, dE = objective(V)
# precon = x-> hessianprecond(V, x)

N = 11
x = [(1-s)*x0 + s*x1 for s in linspace(.0, 1., N)]
t = [((x1-x0)/norm(x1-x0)) for s in linspace(.0, 1., N)]

P = copy(V.A); P[1] = 1.0
precon = x->[P]

path = StringMethod(1./c, tol, maxint, I, (P, x) -> P, 1, false)
PATHx, PATHlog = run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

path = ODEStringMethod(SaddleSearch.ODE12r(atol=1e-7, rtol=1e-0), preconI,
serial(), tol, maxint, 1)
PATHx, PATHlog, _ = SaddleSearch.run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

preconP = SaddleSearch.localPrecon(precon = [P], precon_prep! = (P, x) ->
precon(x), precon_cond = true)

path = PreconStringMethod(preconP, 0.25, -1, false, tol, maxint, 1)
PATHx, PATHlog = run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

path = ODEStringMethod(SaddleSearch.ODE12r(atol=1e-3, rtol=1e-0), preconP,
serial(), tol, maxint, 1)
PATHx, PATHlog, _ = SaddleSearch.run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

heading2("Vacancy migration potential")
V = LJVacancy2D(R = 5.1)
x0, x1 = ic_path(V, :min)
E, dE = objective(V)
# precon = x-> hessianprecond(V, x)

N = 9
x = [(1-s)*x0 + s*x1 for s in linspace(.0, 1., N)]
t = [((x1-x0)/norm(x1-x0)) for s in linspace(.0, 1., N)]

precon = x->[copy(precond(V, xn)) for xn in x]

path = StringMethod(0.001, tol, maxint, I, (P, x) -> P, 1, false)
PATHx, PATHlog = run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

path = ODEStringMethod(SaddleSearch.ODE12r(atol=1e-7, rtol=1e-2), preconI,
serial(), tol, maxint, 1)
PATHx, PATHlog, _ = SaddleSearch.run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

preconP = SaddleSearch.localPrecon(precon = precon(x),
precon_prep! = (P, x) -> precon(x), precon_cond = true)

path = PreconStringMethod(preconP, 1.55, -1, false, tol, maxint, 1)
PATHx, PATHlog = run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res

path = ODEStringMethod(SaddleSearch.ODE12r(atol=1e-2, rtol=1e-2), preconP,
serial(), tol, maxint, 1)
PATHx, PATHlog, _ = SaddleSearch.run!(path, E, dE, x, t)
@test PATHlog[:maxres][end] <= path.tol_res


end