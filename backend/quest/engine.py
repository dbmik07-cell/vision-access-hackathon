"""The single QUEST+ engine for acuity and contrast, on the ease variable x (contract section 5).

Posterior over the full t x beta grid; beta is marginalised and never published.
"""

from collections.abc import Sequence
from dataclasses import dataclass

import numpy as np

from contract import EngineConfig


@dataclass(frozen=True)
class Choice:
    index: int  # into the stimulus list
    expected_entropy: tuple[float, ...]  # one per admissible candidate, in admissible-list order


@dataclass(frozen=True)
class Summary:
    threshold_marginal: tuple[float, ...]
    mean: float  # mean and sd: stop rule only
    sd: float
    median: float
    ci95: tuple[float, float]


@dataclass(frozen=True)
class Result:
    trials: int
    estimate: float
    ci95: tuple[float, float]
    reliability: str
    flags: tuple[str, ...]


def _entropy(posterior: np.ndarray) -> np.ndarray:
    """Natural-log entropy over the last two axes; 0 * ln 0 is taken as 0."""
    positive = posterior > 0
    terms = np.where(positive, posterior * np.log(np.where(positive, posterior, 1.0)), 0.0)
    return -terms.sum(axis=(-2, -1))


class QuestPlus:
    def __init__(self, config: EngineConfig, stimuli: Sequence[float]):
        if config.prior != "uniform":
            raise ValueError(f"prior {config.prior!r} is not defined by the contract (only 'uniform')")
        self._config = config
        self._stimuli = np.asarray(stimuli, dtype=float)
        self._t = np.asarray(config.threshold_grid.points())
        self._beta = np.asarray(config.beta_grid, dtype=float)
        self._posterior = np.full((self._t.size, self._beta.size), 1.0 / (self._t.size * self._beta.size))
        self.trials = 0

    def _p_correct(self, x: np.ndarray) -> np.ndarray:
        """P(correct | x, t, beta), with shape x.shape + (t, beta)."""
        gamma, lam = self._config.gamma, self._config.lam
        x = np.asarray(x)[..., np.newaxis, np.newaxis]
        return gamma + (1 - gamma - lam) / (1 + np.exp(-self._beta * (x - self._t[:, np.newaxis])))

    def choose(self, admissible_indices: Sequence[int]) -> Choice:
        """The admissible stimulus minimising expected posterior entropy; ties go to the lowest position."""
        indices = list(admissible_indices)
        if not indices:
            raise ValueError("no admissible stimuli")
        p_correct = self._p_correct(self._stimuli[indices])
        expected = np.zeros(len(indices))
        for likelihood in (p_correct, 1 - p_correct):
            joint = self._posterior * likelihood
            p_outcome = joint.sum(axis=(-2, -1))
            with np.errstate(divide="ignore", invalid="ignore"):
                updated = joint / p_outcome[:, np.newaxis, np.newaxis]
            expected += np.where(p_outcome > 0, p_outcome * _entropy(updated), 0.0)
        tied = expected <= expected.min() + self._config.tie_epsilon
        return Choice(index=indices[int(np.argmax(tied))], expected_entropy=tuple(expected.tolist()))

    def update(self, stimulus_index: int, correct: bool) -> None:
        """Bayes update with the response to the given stimulus, then renormalise."""
        p_correct = self._p_correct(self._stimuli[stimulus_index])
        self._posterior = self._posterior * (p_correct if correct else 1 - p_correct)
        self._posterior /= self._posterior.sum()
        self.trials += 1

    def _quantile(self, marginal: np.ndarray, q: float) -> float:
        """Bin-uniform piecewise-linear CDF, clipped to [t_min, t_max] (ADR 0002)."""
        h = self._config.threshold_grid.step
        cumulative = np.cumsum(marginal)
        reached = np.flatnonzero((marginal > 0) & (cumulative >= q))
        # Rounding can leave the total just below q = 0.975; the last massive bin then holds it.
        i = int(reached[0]) if reached.size else int(np.flatnonzero(marginal > 0)[-1])
        below = cumulative[i] - marginal[i]
        value = self._t[i] - h / 2 + h * (q - below) / marginal[i]
        return float(np.clip(value, self._t[0], self._t[-1]))

    def summary(self) -> Summary:
        marginal = self._posterior.sum(axis=1)
        mean = float(np.dot(marginal, self._t))
        low_q, high_q = self._config.ci_quantiles
        return Summary(
            threshold_marginal=tuple(marginal.tolist()),
            mean=mean,
            sd=float(np.sqrt(np.dot(marginal, (self._t - mean) ** 2))),
            median=self._quantile(marginal, 0.5),
            ci95=(self._quantile(marginal, low_q), self._quantile(marginal, high_q)),
        )

    def _sd_target_met(self) -> bool:
        return self.trials >= self._config.min_trials and self.summary().sd < self._config.stop_sd

    def should_stop(self) -> bool:
        return self._sd_target_met() or self.trials >= self._config.max_trials

    def result(self) -> Result:
        """Reliability by ci95 width only; the MVP never produces 'unreliable'."""
        summary = self.summary()
        low, high = summary.ci95
        flags = []
        if high - low > self._config.reliable_max_ci_width:
            flags.append("wideInterval")
        if self.trials >= self._config.max_trials and not self._sd_target_met():
            flags.append("maxTrialsReached")
        return Result(
            trials=self.trials,
            estimate=summary.median,
            ci95=summary.ci95,
            reliability="doubtful" if "wideInterval" in flags else "reliable",
            flags=tuple(flags),
        )
