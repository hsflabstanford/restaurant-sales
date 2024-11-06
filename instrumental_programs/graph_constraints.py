import instrumental_programs as iv
import scipy.optimize as opt
import numpy as np

from functools import reduce
from operator import mul


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


def targets(assignments, intervention):
    eq = sorted('{}={}'.format(p, v) for p, v in intervention.items())
    return [
        '{}({})={}'.format(k, ','.join(eq), v)
        for k, v in assignments.items()
    ]


def graph_constraints(graph, potentials, observed, instruments, cards, dist,
                      dist_dims, iv_dist, n, alpha):
    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])

    # cardinalities of observed and IV -- used in uncertainty calculations
    o_levels = reduce(mul, (cards[v] for v in observed))
    if len(instruments) == 0:
        num_distributions = 1
    else:
        num_distributions = reduce(mul, (cards[v] for v in instruments))
    
    for iv_values in iv.all_assignments(instruments, cards):
        iv_prob = iv_dist[tuple(iv_values.values())]

        # observed constraints for distribution conditional on these IV values
        for o_values in iv.all_assignments(observed, cards):
            p = dist[tuple({**iv_values, **o_values}[v] for v in dist_dims)] / iv_prob
            row = iv.marginal(graph, potentials, targets(o_values, iv_values), iv_dist, instruments, cards, alpha)

            if alpha is None:
                a_eq.append(row)
                b_eq.append(p)
            else:
                # calculate sample size for this conditional distribution
                iv_n = n * iv_prob

                l, u = uncertainty_bounds(p, iv_n, o_levels, alpha, num_distributions)
                a_ub += [-row, row]
                b_ub += [-l, u]

    return a_eq, b_eq, a_ub, b_ub
