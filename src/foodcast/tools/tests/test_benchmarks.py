# Public packages
import unittest
import pandas as pd

# Custom packages
import foodcast.tools.benchmarks as benchmarks

class TestBenchmarks(unittest.TestCase):

    def test_approximate_binary_search(self):
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.2,.3,.5,.6]), goal=0.93, tolerance=0.01), 4)
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.2,.28,.5,.6]), goal=0.3, tolerance=0.03), 2)
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.28,.5,.6]), goal=0.3, tolerance=0.03), 1)
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.28,.5,.6]), goal=0.3, tolerance=0.02), 1)
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.28,.5,.6]), goal=0.3, tolerance=0.01), 1)
        self.assertEqual(benchmarks.ParetoAnalysis.approximate_binary_search(sorted_fractions = pd.Series([.1,.2,.28,.5,.6]), goal=0.3, tolerance=0.02), 2)

if __name__ == '__main__':
    unittest.main()