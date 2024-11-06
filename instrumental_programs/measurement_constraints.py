from itertools import product

import numpy as np
import instrumental_programs as iv


# TODO: improve code reuse between intervention and non-intervention versions


def error_bound(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0, distance=0):
    # \sum_{|y - x| > distance} P(Y = y, X = x) <= epsilon

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    row = np.zeros(tuple(c for c in potentials.values())).flatten()
    for i, j in product(range(cards[parent]), repeat=2):
        if np.abs(i - j) <= distance:
            continue

        targets = [
            '{}()={}'.format(parent, i),
            '{}()={}'.format(child, j),
        ]
        row += iv.marginal(graph, potentials, targets, iv_dist, instruments, cards, alpha)

    a_ub.append(row)
    b_ub.append(epsilon)
    return a_eq, b_eq, a_ub, b_ub


def intervention_error_bound(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0, distance=0):
    # \sum_{|y - x| > distance} P(Y(z) = y, X(z) = x) <= epsilon for all z

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    for iv_vals in iv.all_assignments(instruments, cards):
        row = np.zeros(tuple(c for c in potentials.values())).flatten()
        iv_intervention = ','.join(sorted('{}={}'.format(k, v) for k, v in iv_vals.items()))
        for i, j in product(range(cards[parent]), repeat=2):
            if np.abs(i - j) <= distance:
                continue

            targets = [
                '{}({})={}'.format(parent, iv_intervention, i),
                '{}({})={}'.format(child, iv_intervention, j)
            ]
            row += iv.marginal(graph, potentials, targets, iv_dist, instruments, cards, alpha)

        a_ub.append(row)
        b_ub.append(epsilon)
    return a_eq, b_eq, a_ub, b_ub


def symmetry(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0):
    # | P(Y = y, X = x) - P(Y = y', X = x) | <= epsilon, for all |x - y| = |x - y'|

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    for i, j, k in product(range(cards[parent]), repeat=3):
        if np.abs(i - j) != np.abs(i - k) or j == k:
            continue

        targets1 = [
            '{}()={}'.format(parent, i),
            '{}()={}'.format(child, j),
        ]
        row1 = iv.marginal(graph, potentials, targets1, iv_dist, instruments, cards, alpha)

        targets2 = [
            '{}()={}'.format(parent, i),
            '{}()={}'.format(child, k),
        ]
        row2 = iv.marginal(graph, potentials, targets2, iv_dist, instruments, cards, alpha)

        a_ub += [row1 - row2, row2 - row1]
        b_ub += [epsilon, epsilon]

    return a_eq, b_eq, a_ub, b_ub


def intervention_symmetry(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0):
    # | P(Y(z) = y, X(z) = x) - P(Y(z) = y', X(z) = x) | <= epsilon, for all z, |x - y| = |x - y'|

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    for iv_vals in iv.all_assignments(instruments, cards):
        iv_intervention = ','.join(sorted('{}={}'.format(k, v) for k, v in iv_vals.items()))
        for i, j, k in product(range(cards[parent]), repeat=3):
            if np.abs(i - j) != np.abs(i - k) or j == k:
                continue

            targets1 = [
                '{}({})={}'.format(parent, iv_intervention, i),
                '{}({})={}'.format(child, iv_intervention, j),
            ]

            row1 = iv.marginal(graph, potentials, targets1, iv_dist, instruments, cards, alpha)

            targets2 = [
                '{}({})={}'.format(parent, iv_intervention, i),
                '{}({})={}'.format(child, iv_intervention, k),
            ]
            row2 = iv.marginal(graph, potentials, targets2, iv_dist, instruments, cards, alpha)

            a_ub += [row1 - row2, row2 - row1]
            b_ub += [epsilon, epsilon]

    return a_eq, b_eq, a_ub, b_ub


def increasing_errors(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0):
    # P(Y = y, X = x) >= P(Y = y', X = x), for all |x - y| <= |x - y'|

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    for i, j, k in product(range(cards[parent]), repeat=3):
        if np.abs(i - j) <= np.abs(i - k) or j == k:
            continue

        targets1 = [
            '{}()={}'.format(parent, i),
            '{}({}={})={}'.format(child, parent, i, j),
        ]
        row1 = iv.marginal(graph, potentials, targets1, iv_dist, instruments, cards, alpha)

        targets2 = [
            '{}()={}'.format(parent, i),
            '{}({}={})={}'.format(child, parent, i, k),
        ]
        row2 = iv.marginal(graph, potentials, targets2, iv_dist, instruments, cards, alpha)

        a_ub.append(row2 - row1)
        b_ub.append(epsilon)

    return a_eq, b_eq, a_ub, b_ub


def intervention_increasing_errors(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0):
    # P(Y(z) = y, X(z) = x) >= P(Y(z) = y', X(z) = x), for all z, |x - y| <= |x - y'|

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])
    for iv_vals in iv.all_assignments(instruments, cards):
        iv_intervention = ','.join(sorted('{}={}'.format(k, v) for k, v in iv_vals.items()))
        for i, j, k in product(range(cards[parent]), repeat=3):
            if np.abs(i - j) <= np.abs(i - k) or j == k:
                continue

            targets1 = [
                '{}({})={}'.format(parent, iv_intervention, i),
                '{}({})={}'.format(child, iv_intervention, j),
            ]
            row1 = iv.marginal(graph, potentials, targets1, iv_dist, instruments, cards, alpha)

            targets2 = [
                '{}({})={}'.format(parent, iv_intervention, i),
                '{}({})={}'.format(child, iv_intervention, k),
            ]
            row2 = iv.marginal(graph, potentials, targets2, iv_dist, instruments, cards, alpha)

            a_ub.append(row2 - row1)
            b_ub.append(epsilon)

    return a_eq, b_eq, a_ub, b_ub


def positive_effect(graph, cards, potentials, parent, child, iv_dist, instruments, alpha, epsilon=0):
    # \sum_{x >= x', y < y'} P(Y(x) = y, Y(x') = y') <= epsilon

    a_eq, b_eq, a_ub, b_ub = ([], [], [], [])

    row = np.zeros(tuple(c for c in potentials.values())).flatten()
    for h, i, j, k in product(range(cards[parent]), repeat=4):
        if h < i or j >= k:
            continue

        targets = [
            '{}({}={})={}'.format(child, parent, h, j),
            '{}({}={})={}'.format(child, parent, i, k),
        ]
        row += iv.marginal(graph, potentials, targets, iv_dist, instruments, cards, alpha)

    a_ub.append(row)
    b_ub.append(epsilon)

    return a_eq, b_eq, a_ub, b_ub


def assumed_constraints(assumptions, graph, cards, potentials, iv_dist, instruments, alpha):
    # asumptions is a dict with keys: parent, child, type, args
    constraints = ([], [], [], [])

    if assumptions is None:
        return constraints

    funcs = {
        'increasing_errors': increasing_errors,
        'symmetry': symmetry,
        'error_bound': error_bound,
        'intervention_increasing_errors': intervention_increasing_errors,
        'intervention_symmetry': intervention_symmetry,
        'intervention_error_bound': intervention_error_bound,
        'positive_effect': positive_effect,
    }

    for a in assumptions:
        func = funcs[a['type']]
        new_constraints = func(
            graph, cards, potentials,
            a['parent'], a['child'], iv_dist, instruments, alpha, **a['kwargs']
        )
        constraints = (x + y for x, y in zip(constraints, new_constraints))

    return tuple(constraints)
