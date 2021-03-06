# -*- coding: utf-8 -*-
# This code is adapted from https://github.com/nikitakit/self-attentive-parser
import numpy as np

cimport numpy as np
cimport cython

ctypedef np.float32_t DTYPE_t

ORACLE_PRECOMPUTED_TABLE = {}


@cython.boundscheck(False)
def decode(int force_gold, int sentence_len, int num_previous_indices, np.ndarray[DTYPE_t, ndim=2] label_scores, int is_training, gold_tree, label_encoder):
    cdef DTYPE_t NEG_INF = -np.inf

    cdef np.ndarray[DTYPE_t, ndim=2] cloned_label_scores = label_scores.copy()
    cdef np.ndarray[DTYPE_t, ndim=2] value_chart = np.zeros((sentence_len + 1, sentence_len + 1), dtype=np.float32)
    cdef np.ndarray[int, ndim=2] split_idx_chart = np.zeros((sentence_len + 1, sentence_len + 1), dtype=np.int32)
    cdef np.ndarray[int, ndim=2] best_label_chart = np.zeros((sentence_len + 1, sentence_len + 1), dtype=np.int32)

    cdef int label_index_iter
    cdef int length, left, right, span_index
    cdef int oracle_label_index, argmax_label_index
    cdef int best_split, split_idx

    cdef DTYPE_t label_score, split_val, max_split_val

    cdef np.ndarray[int, ndim=2] oracle_label_chart, oracle_split_chart

    if is_training or force_gold:
        if gold_tree in ORACLE_PRECOMPUTED_TABLE:
            oracle_label_chart, oracle_split_chart = ORACLE_PRECOMPUTED_TABLE[gold_tree]
        else:
            oracle_label_chart = np.zeros((sentence_len + 1, sentence_len + 1), dtype=np.int32)
            oracle_split_chart = np.zeros((sentence_len + 1, sentence_len + 1), dtype=np.int32)

            for length in range(1, sentence_len + 1):
                for left in range(0, sentence_len + 1 - length):
                    right = left + length

                    oracle_label_chart[left, right] = label_encoder.transform(gold_tree.oracle_label(left, right))

                    if length == 1:
                        continue

                    oracle_split_chart[left, right] = min(gold_tree.oracle_splits(left, right))

            ORACLE_PRECOMPUTED_TABLE[gold_tree] = oracle_label_chart, oracle_split_chart

    span_index = -1

    for length in range(1, sentence_len + 1):
        for left in range(0, sentence_len + 1 - length):
            right = left + length

            span_index += 1

            if is_training or force_gold:
                oracle_label_index = oracle_label_chart[left, right]

            if force_gold:
                label_score = cloned_label_scores[span_index, oracle_label_index]
                best_label_chart[left, right] = oracle_label_index
            else:
                if is_training:
                    # Augment scores
                    cloned_label_scores[span_index, oracle_label_index] -= 1

                argmax_label_index = int(length >= sentence_len)

                # Compute argmax manually
                label_score = cloned_label_scores[span_index, argmax_label_index]
                for label_index_iter in range(1, cloned_label_scores.shape[1]):
                    if cloned_label_scores[span_index, label_index_iter] > label_score:
                        argmax_label_index = label_index_iter
                        label_score = cloned_label_scores[span_index, label_index_iter]

                best_label_chart[left, right] = argmax_label_index

                if is_training:
                    # Augment scores
                    label_score += 1

            if length == 1:
                value_chart[left, right] = label_score
                continue

            if force_gold:
                best_split = oracle_split_chart[left, right]
            else:
                best_split = left + 1
                split_val = NEG_INF
                for split_idx in range(left + 1, right):
                    max_split_val = value_chart[left, split_idx] + value_chart[split_idx, right]
                    if max_split_val > split_val:
                        best_split = split_idx
                        split_val = max_split_val

            value_chart[left, right] = label_score + value_chart[left, best_split] + value_chart[best_split, right]
            split_idx_chart[left, right] = best_split

    """
    N = 4
    L0: (0, 4)
    L1: (0, 1), (1, 4)
    L2: (1, 2), (2, 4)
    L3: (2, 3), (3, 4)

    Nodes = 2 * N - 1 (full binary tree)
    """
    cdef int i, j, k, l, n

    n = sentence_len

    cdef int num_tree_nodes = 2 * n - 1

    cdef np.ndarray[int, ndim=1] included_i = np.empty(num_tree_nodes, dtype=np.int32)
    cdef np.ndarray[int, ndim=1] included_j = np.empty(num_tree_nodes, dtype=np.int32)
    cdef np.ndarray[int, ndim=1] included_indices = np.empty(num_tree_nodes, dtype=np.int32)
    cdef np.ndarray[int, ndim=1] included_labels = np.empty(num_tree_nodes, dtype=np.int32)

    cdef int idx = 0
    cdef int stack_idx = 1

    cdef np.ndarray[int, ndim=1] stack_i = np.empty(num_tree_nodes + 5, dtype=np.int32)
    cdef np.ndarray[int, ndim=1] stack_j = np.empty(num_tree_nodes + 5, dtype=np.int32)

    stack_i[1] = 0
    stack_j[1] = n

    while stack_idx > 0:
        i = stack_i[stack_idx]
        j = stack_j[stack_idx]

        stack_idx -= 1  # Pop

        included_i[idx] = i
        included_j[idx] = j

        l = j - i

        included_indices[idx] = (n * (n + 1) - (n - l + 1) * (n - l + 2)) >> 1
        included_indices[idx] += i

        included_labels[idx] = best_label_chart[i, j]

        idx += 1

        if i + 1 < j:
            # Select best split point
            k = split_idx_chart[i, j]

            # Insert (k, j)
            stack_idx += 1
            stack_i[stack_idx] = k
            stack_j[stack_idx] = j

            # Insert (i, k)
            stack_idx += 1
            stack_i[stack_idx] = i
            stack_j[stack_idx] = k

    cdef DTYPE_t original_score = 0.0
    for idx in range(num_tree_nodes):
        original_score += label_scores[included_indices[idx], included_labels[idx]]
        included_indices[idx] += num_previous_indices

    cdef DTYPE_t augmented_score = value_chart[0, n]
    cdef DTYPE_t augmented_amount = round(augmented_score - original_score)

    return augmented_score, included_i, included_j, included_indices, included_labels, augmented_amount
