import numpy as np
import instrumental_programs as iv

from itertools import chain
from collections import OrderedDict as dict


def marginal(graph, potentials, targets, iv_dist, instruments, cards, alpha):
    if alpha is not None and any(requires_iv_marginal(t, instruments, graph) for t in targets):
        raise ValueError('Cannot calculate uncertainty when IV marginal is required, for targets {}'.format(targets))

    row = np.zeros(tuple(c for c in potentials.values()))
    for m_vals in iv.all_assignments(potentials, potentials):
        for iv_vals in iv.all_assignments(instruments, cards):
            iv_vals = dict((k + '()', v) for k, v in iv_vals.items())
            if consistent(graph, {**m_vals, **iv_vals}, targets):
                row[tuple(m_vals.values())] += iv_dist[tuple(iv_vals.values())]

    if alpha is not None:
        msg = 'Marginal should not involve P(Z) if uncertainty is to be calculated'
        assert all(np.round(i, 5) in (0, 1) for i in row.flatten()), msg

    return row.flatten()


def consistent(graph, assignment, targets):
    for target in targets:
        intervention = intervention_assignments(target)
        var = target[:target.find('(')]
        po = parent_assignments(var, intervention, graph, assignment)

        target_assignment = int(target.split('=')[-1].strip())
        if assignment[po] != target_assignment:
            return False

    return True


def parent_assignments(var, intervention, graph, assignments):
    parents = get_parents(var, graph)

    if set(intervention).issubset(set(parents)):
        for p in set(parents) - set(intervention):
            intervention[p] = find_value(p, assignments, intervention, graph)

        equals = sorted('{}={}'.format(k, v) for k, v in intervention.items())
        return '{}({})'.format(var, ','.join(equals))

    overlap = set.intersection(set(parents), set(intervention))
    nonoverlap = set(intervention) - set(parents)
    nonoverlap_children = set(
        chain.from_iterable(get_children(n, graph) for n in nonoverlap))
    new_intervention = {
        **{o: intervention[o] for o in overlap},
        **{
            c: find_value(c, assignments, intervention, graph)
            for c in nonoverlap_children
        }
    }
    return parent_assignments(var, new_intervention, graph, assignments)


def find_value(var, assignments, intervention, graph):
    values = intervention.copy()
    for v in filter(lambda x: x not in values, order(graph)):

        parents = get_parents(v, graph)
        equals = list(
            sorted('{}={}'.format(k, v) for k, v in values.items()
                   if k in parents))

        # because of order, all parents will already be in values
        assert len(equals) == len(
            parents), 'not all parents have values assigned'
        po = '{}({})'.format(v, ','.join(equals))
        values[v] = assignments[po]

        if v == var:
            return values[v]


def order(graph):
    ordered = []
    nodes = set(chain.from_iterable(graph))
    while len(ordered) < len(nodes):
        for node in nodes - set(ordered):
            an = get_ancestors(node, graph)
            if all(n in ordered for n in an):
                ordered.append(node)
    return ordered


def get_ancestors(node, graph):
    ancestors = set()
    new_ancestors = {node}

    while len(new_ancestors) != 0:
        all_parents = (get_parents(a, graph) for a in new_ancestors)
        new_ancestors = set(chain.from_iterable(all_parents))
        ancestors.update(new_ancestors)

    return ancestors


def get_parents(node, graph):
    return [e[0] for e in graph if e[1] == node]


def get_children(node, graph):
    return [e[1] for e in graph if e[0] == node]


def intervention_assignments(potential):
    start = potential.find('(')
    end = potential.find(')')
    parents = potential[start + 1:end].split(',')

    if not any(parents) or start == -1:
        return dict()

    return {p[0]: int(p[1]) for p in (p.split('=') for p in parents)}


def swig(graph, interventions):
    return [(s, e) for s, e in graph if s not in interventions]


def active_path(x, y, graph):
    level = {x}
    while len(level) > 0:
        if y in level:
            return True
        level = set(chain(*[iv.get_children(v, graph) for v in level]))

    return False


def requires_iv_marginal(target, instruments, graph):
    assignment = iv.intervention_assignments(target)
    graph = swig(graph, assignment)
    var = target.split('(')[0].strip()
    return any(active_path(i, var, graph) for i in instruments)
