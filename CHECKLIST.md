# Mental Gym: Jev-style System One Model — Build Checklist

This is a mental gym - the task is to build a Jev-style "System One" model from
scratch: a transformer that reads one shared `state` plus several `questions`
in a single forward pass and returns calibrated probability distributions over
typed answers (choice, boolean, numeric) instead of generating tokens. Use this
file as progress tracker.

Some sections are skipped by copying from a reference so you can focus on
building the parts that make Jev different from an LLM (branch attention,
readout heads, calibrated training) while keeping the system runnable
end-to-end. Those phases are annotated as skipped. The transformer backbone is
one of them: Jev post-trains a pretrained language model, so you load a small
pretrained causal LM (e.g. GPT-2 small or Qwen2.5-0.5B) rather than pretrain
your own.

When starting from any section, AI explanations should provide minimum guide for
the user to gain a deep understanding of the design. The purpose is to train as in
a gym, not to allow the user to answer correctly at the first attempt.

DO NOT provide the answer directly.

Reference: Jev has no public implementation. The target design follows Archer
Hume's black-box reconstruction, "Jev's architecture, unmasked"
(https://archerhume.com/posts/jevs-architecture-unmasked), cross-checked
against TypeSafe's launch post
(https://typesafe.ai/blog/introducing-system-one-models-and-jev) and docs
(https://docs.typesafe.ai/llms-full.txt). Prior art for the pieces:
Hydragen (shared-prefix attention, arXiv 2402.05099), FIRST (single-token
listwise scoring, arXiv 2406.15657), Guo et al. 2017 (calibration,
arXiv 1706.04599), Gneiting & Raftery 2007 (proper scoring rules).

Target design: `state` is encoded once; each question becomes a branch that
attends causally to the state and to itself but never to sibling branches; a
readout head at the end of each branch turns the final hidden state into a
distribution over that question's allowed answers; the whole model is trained
with proper scoring rules so the probabilities are calibrated, then measured
with ECE and reliability diagrams.

---

## Phase 1 — Request schema and sequence packing

- [ ] **1.1** Typed request/response dataclasses: `ChoiceQuestion` (option keys + descriptions, max 255), `BooleanQuestion`, `NumericQuestion`, and a `Request` holding one `state` string plus a dict of question-id → question; validate option count and key uniqueness.
- [ ] **1.2** Branch serialization: render one question (instructions + enumerated options with marker tokens) into the text that follows the shared state, and record the character span of each option so it can be mapped to tokens later.
- [ ] **1.3** Sequence packing: tokenize state + N branches into one flat token tensor with a per-token `branch_id` (0 = state), the readout position of each branch, and the token position of each option's last token.

## Phase 2 — Pretrained causal backbone (Skipped for now, will come back)

- [ ] **2.1** Load a small pretrained causal LM from Hugging Face and wrap it so a forward call accepts `input_ids`, a custom 4-D attention mask, and explicit `position_ids`, and returns the final-layer hidden states. Copy this from the transformers docs; the backbone is not the learning target.

## Phase 3 — Shared-state branch attention

- [ ] **3.1** Block attention mask: state tokens attend causally to state; branch tokens attend to all state tokens and causally to their own branch; no branch attends to another branch.
- [ ] **3.2** Branch position ids: every branch continues from `len(state)` so each question sees the same positions it would see if sent alone.
- [ ] **3.3** Isolation test: a request with one question and the same request with three questions yield identical hidden states at that question's readout position (up to float tolerance).
- [ ] **3.4** Shared-prefix KV cache: encode the state once, then run all branch suffixes as a batch against the cached prefix instead of one packed sequence (Hydragen-style).

## Phase 4 — Readout heads

- [ ] **4.1** Slot head for choice questions: a linear layer from the branch's final hidden state to a fixed 255-slot logit vector, masked to the K allowed options, then softmax.
- [ ] **4.2** Pointer head for choice questions: a decision vector from the readout position scored against each option's final-token hidden state (dot product), softmax over the K scores; variable K with no padding slots.
- [ ] **4.3** Boolean head: a scalar readout with sigmoid.
- [ ] **4.4** Numeric head: a distribution over values (start with a binned categorical over a given range, then a Gaussian mean/log-variance variant).
- [ ] **4.5** Confidence summary: the normalised distance above uniform, `c = (p_max - 1/K) / (1 - 1/K)`, computed from the distribution, plus a `Response` object that maps every head's output back to its question id.

## Phase 5 — Calibrated training

- [ ] **5.1** Proper scoring losses: log loss and Brier loss over the choice/boolean distributions, a Gaussian NLL for numeric; a test showing each is minimised by the true probability.
- [ ] **5.2** Dataset builder: convert a multiple-choice benchmark (e.g. MMLU or ARC subsets) into `Request`s that bundle several questions behind one shared state, with label tensors per branch.
- [ ] **5.3** Training step: pack a batch of requests, run backbone + heads, sum the per-branch scoring loss, backprop into the heads with the backbone frozen; then a LoRA or last-N-layers unfrozen variant.
- [ ] **5.4** Outcome-reward variant: sample an answer from `p`, reward it by correctness, and apply a REINFORCE update with a Brier-score baseline; compare against the supervised proper-scoring update on the same data.

## Phase 6 — Calibration measurement and probing

- [ ] **6.1** Reliability diagram and 10-bin expected calibration error (ECE) over a held-out split.
- [ ] **6.2** Temperature scaling fitted on a validation split, re-measuring ECE before and after.
- [ ] **6.3** Option-order probe: permute option order and measure the shift in probability for the correct answer.
- [ ] **6.4** Listwise-interaction probe: add an irrelevant distractor option and measure the log-odds shift between two existing options; compare the slot head and the pointer head.

## Phase 7 — Serving

- [ ] **7.1** Request batching: group requests by state, reuse the prefix cache across them, and map every output back to its request and question id.
- [ ] **7.2** Two-stage large choice sets (K > 255): score each option independently in a first pass, keep the top candidates, then run one explicit choice over them.
- [ ] **7.3** Latency benchmark: time single-question vs 10-question requests with and without the prefix cache, and report tokens counted once per state.

---

## Depth Checkpoints (answer these before moving on)

| After phase | Question to answer yourself |
|---|---|
| 1 | Why does the request bundle many questions behind one state instead of sending one question per call, and what does that choice force on the sequence layout? |
| 2 | Why does post-training a pretrained causal LM beat training a bidirectional encoder from scratch for this task, given that the model never generates a token? |
| 3 | Why must branches be isolated from each other (instead of plain causal attention over the concatenation), and what would answers depend on if they were not? |
| 4 | What does the pointer head buy over the fixed slot head, and why can neither produce independent per-option probabilities? |
| 5 | Why does a proper scoring rule produce calibrated probabilities where RLHF-style preference training produces mode dropping, and why does the outcome-reward variant converge to the same optimum in expectation? |
| 6 | Why can a model with low ECE still be badly wrong on an individual question, and why does temperature scaling fix calibration but never accuracy? |
| 7 | Why can the state prefix be cached across branches and requests but the branch suffixes cannot, and what does that imply for the price of output "tokens"? |

---

_Use the `AI-mental-gym` skill in Claude Code to get interactive help on any phase._
