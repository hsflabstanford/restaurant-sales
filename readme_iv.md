## Installation

From this directory

`pip install -e ./`

will install the package under the name "instrumental_programs" in editable
mode, i.e. changes made to the code will be reflected anywhere it is imported.

## Use

#### Quickstart

The interface into this software is the `build_lp` function. See below for a
simple example corresponding to the LP for the classical IV model, with positive
effect of treatment for at least 0.99 of the population.


```py
import instrumental_programs as iv
import scipy.optimize as opt
import numpy as np


def test_iv():
    graph = [('Z', 'A'), ('A', 'Y')]
    instruments = {'Z'}
    measurements = {'A', 'Y'}
    unobserved = set()
    cardinalities = {'Z': 2, 'A': 2, 'Y': 2}

    dist = np.array([[[0.125, 0.125], [0.125, 0.125]], [[0.125, 0.125], [0.125, 0.125]]])
    dist_dims = ['Z', 'A', 'Y']

    assumptions = [
        {
            'type': 'positive_effect',
            'parent': 'A',
            'child': 'Y',
            'kwargs': {
                'epsilon': 0.01
            },
        },
    ]

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
    print(linprog_args)
    print(opt.linprog(*linprog_args))
```

See the test file in this directory fo additional examples.

#### `build_lp` arguments

The `build_lp` function has the following signature:

```py
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
             alpha=None)
```

**graph**: A list of length-two tuples. Each tuple represent a directed edge.
For example `[('A', 'B'), ('B', 'C')]` represented the graph `A -> B -> C`.

**cards**: A map from variable names to their cardinalities.

**instruments**: The variables in the graph that are instruments. All
instruments are assumed to be mutually confounded, and must have exactly one
child that is in measurements (see below) and no parents.

**measurements**: The variables in the graph that are not instruments. All
measurements are assumed to be mutually confounded.

**unobserved**: Variables of interest that are not observed.

**dist**: A numpy array representing the distribution over observed variables.

**dist_dims**: A list of variables such that the index of each variable is the
same as the axis of `dist` corresponding to that variable. This means for
example that if a variable `X` is at index `2` of `dist_dims`, its marginal
distribution will be given by `np.sum(dist, axis=2)`.

**target_var**: The variable about which we want to make inferences. At present
only inferences about expected values are supported.

**intervention**: The intervention under which we want to make inferences as a
map from variables to their intervention values. E.g. passing `target_var=Y,
intervention={'A': 1, 'Z': 2}` will return bounds for expected value of
`E[Y(A=1, Z=1)]`.

**intervention2**: If `intervention2` is provided, we return bounds on the
contrast of the expected values of the target variable under `intervention` and
`intervention2`.

**assumptions**: A list of assumptions relating two variables in the graph. See
below for details.

**n**: Size of the dataset. 

**alpha**: Level of statistical uncertainty for confidence bounds. `alpha=0.05`
will yield 95% confidence bounds. If `alpha=None`, the empirical distribution is
used and no account is taken of statistical uncertainty. If `alpha` is not
`None`, `n` must also not be `None`.

#### Assumptions

Assumptions relate two variables, a `parent` and a `child`. Each assumption
currently supported has a `type` and a set of `kwargs`. Assumptions for the
`build_lp` function are represented as a list of dictionaries, where each
dictionary corresponds to one assumption. The dictionary should have the keys
`parent`, `child`, `type`, and `kwargs`. See quickstart and the test file for
examples, or `measurement_constraints.py` for details. In the summaries below,
`X` represents the parent and `Y` represents the child.


**error_bound**: kwargs are epsilon and distance. The assumption states 
`\sum_{|y - x| > distance} P(Y = y, X = x) <= epsilon`, i.e. there is a known
upper bound of `epsilon` on the proportion of the population for which observed
measurement error exceeds `distance`. 

**symmetry**: kwargs are epsilon. The assumption states
`| P(Y = y, X = x) - P(Y = y', X = x) | <= epsilon, for all |x - y| = |x - y'|`,
i.e. the probability of errors of the same magnitude in different directions is
epsilon close.

**positive_effect**: kwargs are epsilon. The assumption states `\sum_{x >= x', y
< y'} P(Y(x) = y, Y(x') = y') <= epsilon`. 

**increasing_errors**: kwargs are epsilon. The assumption states `P(Y = y, X =
x) - P(Y = y', X = x) >= epsilon, for all |x - y| <= |x - y'|`.

## Running tests

Tests can be run with pytest, e.g. 

`pytest test.py -s -v`

for verbose runs w/ captured standard out. See pytest documentation for more
options.

Single tests can be run with e.g.

`pytest test.py::iv_test -s -v`.
