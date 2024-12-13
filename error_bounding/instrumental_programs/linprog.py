import numpy as np
import instrumental_programs as iv

from collections import OrderedDict as dict
from itertools import product
from functools import reduce
from operator import add


def merge(*constraints):
    merged = []
    for arrays in zip(*constraints):
        added = reduce(add, arrays)
        merged.append(np.stack(added) if len(added) > 0 else None)
    return merged


def prob_constraints(potentials):
    row = np.ones(tuple(c for c in potentials.values()))
    return [row.flatten()], [1], [], []


def has_parent(graph, v):
    return any(e[1] == v for e in graph)


def all_assignments(variables, cardinalities):
    variables = list(variables)  # need definite ordering
    return [
        dict((v, a) for v, a in zip(variables, p))
        for p in product(*[range(cardinalities[v]) for v in variables])
    ]


def get_potentials(graph, instruments, cards):
    potentials = dict()
    for v in sorted(set(cards) - set(instruments)):
        assignments = all_assignments(iv.get_parents(v, graph), cards)
        for assignment in assignments:
            eq = ('{}={}'.format(p, v) for p, v in assignment.items())
            name = '{}({})'.format(v, ','.join(sorted(eq)))
            potentials[name] = cards[v]
    return potentials


def iv_distribution_relevant(row, potentials, instruments, cards):
    row = row.reshape(tuple(c for c in potentials.values()))

    for i, instrument in enumerate(instruments):
        axis = list(potentials).index('{}()'.format(instrument))
        row = np.swapaxes(row, i, axis)

    # check if potential outcome parameters differ between instruments
    return any(
        np.any(row[tuple(0 for _ in instruments)] != row[assignment])
        for assignment in product(*[range(cards[i]) for i in instruments])
    )


def cost(graph, potentials, var, cards, iv_dist, instruments, alpha, intervention, intervention2=None, cost_fun=None):
    # if two interventions, assume we want a causal contrast
    if intervention2 is not None:
        c1 = cost(graph, potentials, var, cards, iv_dist, instruments, alpha, intervention, cost_fun=cost_fun)
        c2 = cost(graph, potentials, var, cards, iv_dist, instruments, alpha, intervention2, cost_fun=cost_fun)
        return c1 - c2

    equals = sorted('{}={}'.format(k, v) for k, v in intervention.items())
    card = cards[var]
    row = np.zeros(tuple(c for c in potentials.values())).flatten()
    for i in range(card):
        target = ['{}({})={}'.format(var, ','.join(equals), i)]
        if cost_fun is None:
            row += i * iv.marginal(graph, potentials, target, iv_dist, instruments, cards, alpha)
        else:
            print((i,cost_fun(i)))
            row += cost_fun(i) * iv.marginal(graph, potentials, target, iv_dist, instruments, cards, alpha)

    return row


def build_lp(graph,
             cards,
             instruments,
             measurements,
             unobserved,
             dist,
             dist_dims,
             target_var,
             intervention,
             intervention2=None,
             assumptions=None,
             n=None,
             alpha=None,
             cost_fun=None):
    """
    Accepts IV type graphs - assumes all instruments are mutual confounded and
    all non-instruments are mutuall confounded.
    ---

    see readme for details
    """
    alpha = alpha if n is not None else None
    assert not any(has_parent(graph, v) for v in instruments)

    observed = set(measurements) - set(unobserved)

    # ensure correct order relative to axes in distribution
    instruments = [i for i in dist_dims if i in instruments]
    observed = [i for i in dist_dims if i in measurements]
    potentials = get_potentials(graph, instruments, cards)

    # marginalize out non-instruments for IV distribution
    iv_dist = np.sum(dist, axis=tuple(dist_dims.index(i) for i in observed))

    c = cost(
        graph, potentials, target_var, cards, iv_dist, instruments, alpha,
        intervention, intervention2, cost_fun
    )

    m_constraints = iv.assumed_constraints(assumptions, graph, cards, potentials, iv_dist, instruments, alpha,)
    g_constraints = iv.graph_constraints(
        graph, potentials, observed, instruments, cards,
        dist, dist_dims, iv_dist, n, alpha
    )
    p_constraints = prob_constraints(potentials)

    a_eq, b_eq, a_ub, b_ub = merge(m_constraints, g_constraints, p_constraints)
    return c, a_ub, b_ub, a_eq, b_eq
