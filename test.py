import instrumental_programs as iv
import scipy.optimize as opt
import numpy as np


def test_order():
    graph = [('B', 'C'), ('D', 'B'), ('A', 'B')]
    order = iv.order(graph)
    assert set(order[:2]) == {'A', 'D'}
    assert order[2:] == ['B', 'C']


def test_find_value():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    assignments = {
        'A()': 0,
        'D()': 0,
        'B(A=0)': 0,
        'B(A=1)': 1,
        'C(B=0,D=0)': 0,
        'C(B=0,D=1)': 1,
        'C(B=1,D=0)': 2,
        'C(B=1,D=1)': 3,
    }

    assert iv.find_value('A', assignments, {}, graph) == 0
    assert iv.find_value('B', assignments, {}, graph) == 0
    assert iv.find_value('B', assignments, {'A': 1}, graph) == 1
    assert iv.find_value('C', assignments, {'A': 1}, graph) == 2
    assert iv.find_value('C', assignments, {'A': 1, 'D': 1}, graph) == 3
    assert iv.find_value('C', assignments, {'D': 1}, graph) == 1
    assert iv.find_value('C', assignments, {}, graph) == 0
    assert iv.find_value('C', assignments, {'D': 0, 'B': 1}, graph) == 2


def test_parent_assignments():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    assignments = {
        'A()': 0,
        'D()': 0,
        'B(A=0)': 0,
        'B(A=1)': 1,
        'C(B=0,D=0)': 0,
        'C(B=0,D=1)': 1,
        'C(B=1,D=0)': 2,
        'C(B=1,D=1)': 3,
    }

    assert iv.parent_assignments('B', {}, graph, assignments) == 'B(A=0)'
    assert iv.parent_assignments('B', {'A': 1}, graph, assignments) == 'B(A=1)'
    assert iv.parent_assignments('C', {'A': 1}, graph, assignments) == 'C(B=1,D=0)'
    assert iv.parent_assignments('C', {'D': 1}, graph, assignments) == 'C(B=0,D=1)'
    assert iv.parent_assignments('C', {'B': 1, 'D': 1}, graph, assignments) == 'C(B=1,D=1)'


def test_consistent():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    assignments = {
        'A()': 0,
        'D()': 0,
        'B(A=0)': 0,
        'B(A=1)': 1,
        'C(B=0,D=0)': 0,
        'C(B=0,D=1)': 1,
        'C(B=1,D=0)': 2,
        'C(B=1,D=1)': 3,
    }

    assert not iv.consistent(graph, assignments, ['C(A=0)=1'])
    assert iv.consistent(graph, assignments, ['C(A=0)=0'])
    assert iv.consistent(graph, assignments, ['C(A=1,D=1)=3'])
    assert iv.consistent(graph, assignments, ['C(A=1,D=1)=3', 'A()=0'])
    assert not iv.consistent(graph, assignments, ['C(A=1,D=1)=2'])
    assert iv.consistent(graph, assignments, ['C(B=1)=2'])
    assert not iv.consistent(graph, assignments, ['A()=0, D()=1'])


def test_swig():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    swig = [('B', 'C'), ('D', 'C')]
    assert iv.swig(graph, ['A']) == swig
    swig = [('A', 'B'), ('D', 'C')]
    assert iv.swig(graph, ['B']) == swig


def test_active_path():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    assert not iv.active_path('D', 'A', graph)
    assert not iv.active_path('A', 'D', graph)
    assert iv.active_path('A', 'C', graph)
    assert iv.active_path('A', 'B', graph)
    assert not iv.active_path('B', 'D', graph)


def test_requires_iv_marginal():
    graph = [('A', 'B'), ('B', 'C'), ('D', 'C')]
    instruments = ['A']
    assert not iv.requires_iv_marginal('B(A=0)=0', instruments, graph)
    assert not iv.requires_iv_marginal('D(A=0)=0', instruments, graph)
    assert not iv.requires_iv_marginal('C(A=0)=0', instruments, graph)
    assert not iv.requires_iv_marginal('C(B=0)=0', instruments, graph)
    assert iv.requires_iv_marginal('C()=0', instruments, graph)
    assert iv.requires_iv_marginal('C(B=0)=0', ['A', 'D'], graph)


def test_iv():
    graph = [('Z', 'A'), ('A', 'Y')]
    instruments = {'Z'}
    measurements = {'A', 'Y'}
    unobserved = set()
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2}

    dist = np.array([
        [[0.24768822, 0.17619026], [0.08733049, 0.13037689]],
        [[0.10431703, 0.00655250], [0.12569444, 0.12185017]]
    ])

    dist_dims = ['Z', 'Y', 'A']
    c, a_ub, b_ub, a_eq, b_eq = iv.build_lp(graph,
                                            cardinalities,
                                            instruments,
                                            measurements,
                                            unobserved,
                                            dist,
                                            dist_dims,
                                            target_var='Y',
                                            intervention={'A': 0},
                                            intervention2={'A': 1})

    # see balke thesis pages 89 - 90
    expected_a_eq = np.array([
       [1., 1., 0., 0., 1., 1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.],
       [0., 0., 0., 0., 0., 0., 0., 0., 1., 0., 1., 0., 1., 0., 1., 0.],
       [0., 0., 1., 1., 0., 0., 1., 1., 0., 0., 0., 0., 0., 0., 0., 0.],
       [0., 0., 0., 0., 0., 0., 0., 0., 0., 1., 0., 1., 0., 1., 0., 1.],
       [1., 1., 0., 0., 0., 0., 0., 0., 1., 1., 0., 0., 0., 0., 0., 0.],
       [0., 0., 0., 0., 1., 0., 1., 0., 0., 0., 0., 0., 1., 0., 1., 0.],
       [0., 0., 1., 1., 0., 0., 0., 0., 0., 0., 1., 1., 0., 0., 0., 0.],
       [0., 0., 0., 0., 0., 1., 0., 1., 0., 0., 0., 0., 0., 1., 0., 1.],
       [1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1.]]
    )
    assert np.allclose(a_eq, expected_a_eq)

    expected_b_eq = np.array([
        dist[0, 0, 0] / dist[0].sum(),
        dist[0, 0, 1] / dist[0].sum(),
        dist[0, 1, 0] / dist[0].sum(),
        dist[0, 1, 1] / dist[0].sum(),
        dist[1, 0, 0] / dist[1].sum(),
        dist[1, 0, 1] / dist[1].sum(),
        dist[1, 1, 0] / dist[1].sum(),
        dist[1, 1, 1] / dist[1].sum(),
        1
    ])
    assert np.allclose(b_eq, expected_b_eq)

    expected_c = np.array(
        [0., 1., -1., 0., 0., 1., -1., 0., 0., 1., -1., 0., 0., 1., -1., 0.]
    )
    assert np.allclose(-c, expected_c)


def test_iv_with_uncertainty():
    graph = [('Z', 'A'), ('A', 'Y')]
    instruments = {'Z'}
    measurements = {'A', 'Y'}
    unobserved = set()
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2}

    dist = np.array([
        [[0.24768822, 0.17619026], [0.08733049, 0.13037689]],
        [[0.10431703, 0.00655250], [0.12569444, 0.12185017]]
    ])
    dist_dims = ['Z', 'Y', 'A']

    c, a_ub, b_ub, a_eq, b_eq = iv.build_lp(graph,
                                            cardinalities,
                                            instruments,
                                            measurements,
                                            unobserved,
                                            dist,
                                            dist_dims,
                                            target_var='Y',
                                            intervention={'A': 0},
                                            intervention2={'A': 1},
                                            alpha=0.05,
                                            n=100)
    expected_a_ub = np.array([
        [-1., -1., -0., -0., -1., -1., -0., -0., -0., -0., -0., -0., -0., -0., -0., -0.],
        [ 1.,  1.,  0.,  0.,  1.,  1.,  0.,  0.,  0.,  0.,  0.,  0.,  0., 0.,  0.,  0.],
        [-0., -0., -0., -0., -0., -0., -0., -0., -1., -0., -1., -0., -1., -0., -1., -0.],
        [ 0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  1.,  0.,  1.,  0.,  1., 0.,  1.,  0.],
        [-0., -0., -1., -1., -0., -0., -1., -1., -0., -0., -0., -0., -0., -0., -0., -0.],
        [ 0.,  0.,  1.,  1.,  0.,  0.,  1.,  1.,  0.,  0.,  0.,  0.,  0., 0.,  0.,  0.],
        [-0., -0., -0., -0., -0., -0., -0., -0., -0., -1., -0., -1., -0., -1., -0., -1.],
        [ 0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  0.,  1.,  0.,  1.,  0., 1.,  0.,  1.],
        [-1., -1., -0., -0., -0., -0., -0., -0., -1., -1., -0., -0., -0., -0., -0., -0.],
        [ 1.,  1.,  0.,  0.,  0.,  0.,  0.,  0.,  1.,  1.,  0.,  0.,  0., 0.,  0.,  0.],
        [-0., -0., -0., -0., -1., -0., -1., -0., -0., -0., -0., -0., -1., -0., -1., -0.],
        [ 0.,  0.,  0.,  0.,  1.,  0.,  1.,  0.,  0.,  0.,  0.,  0.,  1., 0.,  1.,  0.],
        [-0., -0., -1., -1., -0., -0., -0., -0., -0., -0., -1., -1., -0., -0., -0., -0.],
        [ 0.,  0.,  1.,  1.,  0.,  0.,  0.,  0.,  0.,  0.,  1.,  1.,  0., 0.,  0.,  0.],
        [-0., -0., -0., -0., -0., -1., -0., -1., -0., -0., -0., -0., -0., -1., -0., -1.],
        [ 0.,  0.,  0.,  0.,  0.,  1.,  0.,  1.,  0.,  0.,  0.,  0.,  0., 1.,  0.,  1.]
    ])
    assert np.allclose(expected_a_ub, a_ub)

    conditionals = [
        dist[0, 0, 0] / dist[0].sum(),
        dist[0, 0, 1] / dist[0].sum(),
        dist[0, 1, 0] / dist[0].sum(),
        dist[0, 1, 1] / dist[0].sum(),
        dist[1, 0, 0] / dist[1].sum(),
        dist[1, 0, 1] / dist[1].sum(),
        dist[1, 1, 0] / dist[1].sum(),
        dist[1, 1, 1] / dist[1].sum(),
    ]
    last_result = -1
    uncertainty_bounds = {i: 2 for i in range(len(conditionals))}
    for n in list(range(100, 1000, 100)) + [None]:
        c, a_ub, b_ub, a_eq, b_eq = iv.build_lp(graph,
                                                cardinalities,
                                                instruments,
                                                measurements,
                                                unobserved,
                                                dist,
                                                dist_dims,
                                                target_var='Y',
                                                intervention={'A': 0},
                                                intervention2={'A': 1},
                                                alpha=0.05,
                                                n=n)
        if n is not None:
            for i, cond in enumerate(conditionals):
                # uncertainty bounds shrink as n grows
                assert -b_ub[i * 2] <= cond <= b_ub[(i * 2) + 1]
                assert b_ub[(i * 2) + 1] - -b_ub[i * 2] <= uncertainty_bounds[i]
                uncertainty_bounds[i] = b_ub[(i * 2) + 1] - -b_ub[i * 2]

        res = opt.linprog(c, a_ub, b_ub, a_eq, b_eq)
        # uncerainty just relaxes bounds
        assert last_result <= res.fun
        last_result = res.fun


def test_two_proxy():
    graph = [('Z', 'A'), ('A', 'Y')]
    instruments = {'Z'}
    measurements = {'A', 'Y'}
    unobserved = {'A'}
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2}

    dist = np.array([
        [[0.24768822, 0.17619026], [0.08733049, 0.13037689]],
        [[0.10431703, 0.00655250], [0.12569444, 0.12185017]]
    ]).sum(axis=2)

    dist_dims = ['Z', 'Y']

    c, a_ub, b_ub, a_eq, b_eq = iv.build_lp(graph,
                                            cardinalities,
                                            instruments,
                                            measurements,
                                            unobserved,
                                            dist,
                                            dist_dims,
                                            target_var='Y',
                                            intervention={'A': 0},
                                            intervention2={'A': 1},
                                            n=1000,
                                            alpha=None)

    expected_a_eq = np.array([
        [1., 1., 0., 0., 1., 1., 0., 0., 1., 0., 1., 0., 1., 0., 1., 0.],
        [0., 0., 1., 1., 0., 0., 1., 1., 0., 1., 0., 1., 0., 1., 0., 1.],
        [1., 1., 0., 0., 1., 0., 1., 0., 1., 1., 0., 0., 1., 0., 1., 0.],
        [0., 0., 1., 1., 0., 1., 0., 1., 0., 0., 1., 1., 0., 1., 0., 1.],
        [1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1., 1.]
    ])
    assert np.allclose(expected_a_eq, a_eq)

    expected_b_eq = np.array([
        dist[0, 0] / dist[0].sum(),
        dist[0, 1] / dist[0].sum(),
        dist[1, 0] / dist[1].sum(),
        dist[1, 1] / dist[1].sum(),
        1
    ])
    assert np.allclose(expected_b_eq, b_eq)


def test_two_proxy_factual():
    graph = [('Z', 'A'), ('A', 'Y')]
    instruments = {'Z'}
    measurements = {'A', 'Y'}
    unobserved = {'A'}
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2}

    dist = np.array([
        [[0.24768822, 0.17619026], [0.08733049, 0.13037689]],
        [[0.10431703, 0.00655250], [0.12569444, 0.12185017]]
    ]).sum(axis=2)

    dist_dims = ['Z', 'Y']

    c, a_ub, b_ub, a_eq, b_eq = iv.build_lp(graph,
                                            cardinalities,
                                            instruments,
                                            measurements,
                                            unobserved,
                                            dist,
                                            dist_dims,
                                            target_var='Y',
                                            intervention={})

    # potentials = OrderedDict([('A(Z=0)', 2), ('A(Z=1)', 2), ('Y(A=0)', 2), ('Y(A=1)', 2)])

    expected_c = np.zeros((2, 2, 2, 2))
    expected_c[0, 0, 0, 0] = 0
    expected_c[0, 0, 0, 1] = 0
    expected_c[0, 0, 1, 0] = 1
    expected_c[0, 0, 1, 1] = 1
    expected_c[0, 1, 0, 0] = 0
    expected_c[0, 1, 0, 1] = dist[1].sum()
    expected_c[0, 1, 1, 0] = dist[0].sum()
    expected_c[0, 1, 1, 1] = 1
    expected_c[1, 0, 0, 0] = 0
    expected_c[1, 0, 0, 1] = dist[0].sum()
    expected_c[1, 0, 1, 0] = dist[1].sum()
    expected_c[1, 0, 1, 1] = 1
    expected_c[1, 1, 0, 0] = 0
    expected_c[1, 1, 0, 1] = 1
    expected_c[1, 1, 1, 0] = 0
    expected_c[1, 1, 1, 1] = 1
    assert np.allclose(expected_c.flatten(), c)


def test_differential_measurement_error():
    # T is observed treatment, A is real treatment (unobserved)
    graph = [('Z', 'A'), ('A', 'Y'), ('Y', 'T'), ('A', 'T')]
    instruments = {'Z'}
    measurements = {'A', 'Y', 'T'}
    unobserved = {'A'}
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2, 'T': 2}
    dist = np.array([
        [[0.24768822, 0.17619026], [0.08733049, 0.13037689]],
        [[0.10431703, 0.00655250], [0.12569444, 0.12185017]]
    ])
    dist_dims = ['Z', 'Y', 'T']

    assumptions = [
        {
            'type': 'intervention_error_bound',
            'parent': 'A',
            'child': 'T',
            'kwargs': {'epsilon': 0.01},
        }
    ]

    # most an example - should run all the way through
    linprog_args = iv.build_lp(graph,
                               cardinalities,
                               instruments,
                               measurements,
                               unobserved,
                               dist,
                               dist_dims,
                               target_var='Y',
                               intervention={'A': 0},
                               intervention2={'A': 1},
                               assumptions=assumptions,
                               n=1000,
                               alpha=0.05)
