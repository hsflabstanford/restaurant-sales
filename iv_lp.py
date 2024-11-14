import numpy as np
from scipy.optimize import linprog
import itertools as it
import time
import scipy.optimize as opt

def kl_bernoulli(p, q):
    return p * np.log2(p / q) + (1 - p) * np.log2((1 - p) / (1 - q))

def uncertainty_bounds(p, n, card, alpha, num_distributions=1):
    def fun(q):
        return kl_bernoulli(p, q) - np.log(2 * card / alpha) / n

    # alpha needs to be calibrated for the number of distributions
    alpha = 1 - (1 - alpha)**(1 / num_distributions)
    lower = 0 if fun(1e-10) <= 0 else opt.bisect(fun, 1e-10, p)
    upper = 1 if fun(1 - 1e-10) <= 0 else opt.bisect(fun, p, 1 - 1e-10)

    return lower, upper

def get_lp(pzty,
           lamb,
           error_bound_args,
           err_const=True,
           mon_const=True,
           sym_const=True,
           pos_effect_of_treatment=True,
           pos_effect_of_truth=True,
           exp_const=False,
           parameter="ate",
           fun=None,
           n=1000,
           alpha=1.0,
           sample_sizes=None):
    
    """
        Calculate bounds for various parameters from the potential
        outcome distribution P(X(A=a),X(A=b),Y(X=1),...,Y(X=K)). 
        
        Arguments:
        
        pzty - (2,2,K) numpy array: 
            P(instrument,treatment,measurment)
            
        lamb - float: 
            Slack on (A2).
            
        error_bound_args - list of tuples:
            A list of length 2 tuples (delta,epsilon). The error bound constraint
            is enforced for each tuple as:
            \sum_{x,y: |x-y| > delta} P(X(t)=x,Y(x)=y) <= epsilon.
            
        err_const - bool:
            Include total error constraint (A0).
            
        mon_const - bool:
            Include monotonicity constraint (A2).
            
        sym_const - bool:
            Include symmetry constraint (A3).
            
        pos_effect_of_treatment - bool:
            Include positive effect of treatment on truth constraint (A5).
            
        pos_effect_of_truth - bool:
            Include positive effect of truth on proxy constraint (A6).
           
        exp_const - bool:
           include equal expectations constraint
            
        parameter - string:
            Possible values are {"ex_t0","ex_t1","ate"} for E[X(T=0)], 
            E[X(T=1)], and E[X(T=1)] - E[X(T=0)]
            
        fun - function taking a value of X and returning a real:
            If not None, then the target parameter is E[fun(X(T=0))]
           
        n - int:
           Total number of samples
           
        alpha - float between 0 and 1:
           Confidence interval param
           
        sample_sizes - tuple (int,int):
           Number of samples in each instrumental arm. If None, calculated from
           P(Z) and n. Use if using an alternate sample size calculation (e.g.,
           due to weighting)
        
    """
           
    if fun is None:
        def fun(x):
            return x
         
    pz = np.sum(pzty,axis=(1,2))
    if sample_sizes is None:
        nz = n*pz
    else:
        nz = sample_sizes.copy()
    pty_z = pzty/pz.reshape((2,1,1))
            
    K = pty_z.shape[-1]
    
    # Shape of the joint distribution, \psi
    joint_shape = [2,2,K,K] + [K]*K
    
    assert parameter in {"ate","ex0","ex1"}
    
    # Create objective function weights
    c = np.zeros(joint_shape)
    for joint_assignment in it.product(*[range(c) for c in joint_shape]):
        x_t0 = joint_assignment[2]
        x_t1 = joint_assignment[3]
        # E[X(a)]
        if parameter == "ex_t0":
            c[joint_assignment] = fun(x_t0)
        # E[X(b)]
        elif parameter == "ex_t1":
            c[joint_assignment] = fun(x_t1)
        # E[X(a) - X(b)]
        elif parameter == "ate":
            c[joint_assignment] = fun(x_t1) - fun(x_t0)
            
    c = c.flatten()
    
    # Equality constraints
    A_eq = []
    b_eq = []
    
    # Inequality (upper bound) constraints
    A_ub = []
    b_ub = []
    
    A_eq.append(np.ones(joint_shape).flatten())
    b_eq.append(1)
    
    
    # observed data constraint
    # \sum_{x,x',y'} \phi_{xx'yy'} = P(Y(a)=y)
    if alpha == 1:
        for z in range(2):
            for t in range(2):
                for y in range(K):
                    a = np.zeros(joint_shape)
                    for x in range(K):
                        slc = [slice(None)]*(K+4)
                        slc[z] = t
                        slc[2+t] = x
                        slc[4+x] = y
                        a[tuple(slc)] = 1
                    A_eq.append(a.flatten())
                    b_eq.append(pty_z[z,t,y])
            
    else:
        for z in range(2):
            for t in range(2):
                for y in range(K):
                    a = np.zeros(joint_shape)
                    for x in range(K):
                        slc = [slice(None)]*(K+4)
                        slc[z] = t
                        slc[2+t] = x
                        slc[4+x] = y
                        a[tuple(slc)] = 1
                    iv_n = nz[z]
                    o_levels = 2*K
                    num_distributions = 2
                    l, u = uncertainty_bounds(pty_z[z,t,y], iv_n, o_levels, alpha, num_distributions)
                
                    A_ub.append(-a.flatten())
                    b_ub.append(-l)

                    A_ub.append(a.flatten())
                    b_ub.append(u)
    
    # Positive effect of treatment on truth
    # \sum_x \sum_{x' > x} P(Y(x') < Y(x)) = 0
    if pos_effect_of_truth:
        a = np.zeros(joint_shape)
        for x_z0 in range(K):
            for x_z1 in range(x_z0+1,K):
                for y_x_z1 in range(K):
                    for y_x_z0 in range(y_x_z1+1,K):
                        slc = [slice(None)]*(K+4)
                        slc[4+x_z0] = y_x_z0
                        slc[4+x_z1] = y_x_z1
                        a[tuple(slc)] = 1
        A_eq.append(a.flatten())
        b_eq.append(0)
        
    # Positive effect of truth on proxy
    # \sum_{x_z0} \sum_{x_z1 < x_z0} P(X(T=0)=x_z0,X(T=1)=x_z1) = 0
    if pos_effect_of_treatment:
        a = np.zeros(joint_shape)
        for x in range(K):
            for xp in range(x):
                a[:,:,x,xp] = 1
        A_ub.append(a.flatten())
        b_ub.append(1e-8)
    
    # bound on proportion of errors
    # \sum_{x,y: |x-y| > delta} P(X(t)=x,Y(x)=y) <= \epsilon for all t
    if err_const:
        for delta,eps in error_bound_args:
            for z in range(2):
                a = np.zeros(joint_shape)
                for t in range(2):
                    for x in range(K):
                        for y in range(K):
                            if np.abs(x-y) > delta:
                                slc = [slice(None)]*(K+4)
                                slc[z] = t
                                slc[2+t] = x
                                slc[4+x] = y
                                a[tuple(slc)] = 1
                A_ub.append(a.flatten())
                b_ub.append(eps)
    
    # monotonicity constraint
    # P(X(t)=x,Y(x)=y) - P(X(t)=x,Y(x)=y') <= 0 for all |x - y| > |x - y'| for all t
    if mon_const:
        for z in range(2):
            for t in range(2):
                for x,y,yp in it.product(range(K),repeat=3):
                    if np.abs(x-y) < np.abs(x-yp):
                        a = np.zeros(joint_shape)
                        slc = [slice(None)]*(K+4)
                        slc[z] = t
                        slc[2+t] = x
                        slc[4+x] = y
                        a[tuple(slc)] = -1
                        slc[4+x] = yp
                        a[tuple(slc)] = 1
                        A_ub.append(a.flatten())
                        b_ub.append(1e-8)
                        
                    
    # symmetry constraint
    # |P(X(t)=x,Y(x)=y) - P(X(t)=x,Y(x)=y')| <= lamb for all |x - y| = |x - y'|
    if sym_const:
        for z in range(2):
            for t in range(2):
                for x,y,yp in it.product(range(K),repeat=3):
                    if np.abs(x-y) == np.abs(x-yp) and y != yp:
                        a = np.zeros(joint_shape)
                        slc = [slice(None)]*(K+4)
                        slc[z] = t
                        slc[2+t] = x
                        slc[4+x] = y
                        a[tuple(slc)]  = 1
                        slc[4+x] = yp
                        a[tuple(slc)] = -1
                        A_ub.append(a.flatten())
                        b_ub.append(lamb)

                        a = np.zeros(joint_shape)
                        slc = [slice(None)]*(K+4)
                        slc[z] = t
                        slc[2+t] = x
                        slc[4+x] = y
                        a[tuple(slc)]  = 1
                        slc[4+x] = yp
                        a[tuple(slc)] = -1
                        A_ub.append(a.flatten())
                        b_ub.append(lamb)
                        
    # Equal expectations constraint
    # E[X] = E[Y]         
    if exp_const:
        for z in range(2):
            a = np.zeros(joint_shape)
            for t,x,y in it.product(range(2),range(K),range(K)):
                slc = [slice(None)]*(K+4)
                slc[z] = t
                slc[2+t] = x
                slc[4+x] = y
                a[tuple(slc)] = x - y
            A_ub.append(a.flatten())
            b_ub.append(1e-8)
        
            A_ub.append(-a.flatten())
            b_ub.append(-1e-8)
                    
    # non-negativity
    bounds = []
    for x in it.product(range(K),repeat=2+K):
        bounds.append((0,1))

    A_eq = np.array(A_eq)
    b_eq = np.array(b_eq)
    
    if len(A_ub) == 0:
        A_ub = None
        b_ub = None
    else:
        A_ub = np.array(A_ub)
        b_ub = np.array(b_ub)
    
    return c,A_eq,b_eq,A_ub,b_ub,bounds
    
def get_iv_bounds(pzty,
               lamb,
               error_bound_args,
               err_const=True,
               mon_const=True,
               sym_const=True,
               exp_const=False,
               pos_effect_of_treatment=True,
               pos_effect_of_truth=True,
               parameter="ate",
               n=1000,
               alpha=1.0,
               fun=None,
               x0=[None,None],
               sample_sizes=None):
    
    # Get LP params
    c,A_eq,b_eq,A_ub,b_ub,bounds = get_lp(pzty,
                                          lamb,
                                          error_bound_args,
                                          err_const=err_const,
                                          mon_const=mon_const,
                                          sym_const=sym_const,
                                          exp_const=exp_const,
                                          pos_effect_of_treatment=pos_effect_of_treatment,
                                          pos_effect_of_truth=pos_effect_of_truth,
                                          parameter=parameter,
                                          fun=fun,
                                          n=n,
                                          alpha=alpha,
                                          sample_sizes=sample_sizes)

    # Solve for lower bound
    lb_res = linprog(c,A_eq=A_eq,b_eq=b_eq,A_ub=A_ub,b_ub=b_ub,method="revised simplex",options={"maxiter":5000,"tol":2e-8})
    
    # Solve for upper bound
    ub_res = linprog(-c,A_eq=A_eq,b_eq=b_eq,A_ub=A_ub,b_ub=b_ub,method="revised simplex",options={"maxiter":5000,"tol":2e-8})
    
    return lb_res.fun,-ub_res.fun,lb_res,ub_res,{'c':c,'A_ub':A_ub,'b_ub':b_ub,'A_eq':A_eq,'b_eq':b_eq}