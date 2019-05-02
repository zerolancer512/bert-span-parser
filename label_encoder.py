# -*- coding: utf-8 -*-
import collections


class LabelEncoder(object):
    def __init__(self):
        self.__values = {}
        self.__indices = {}

    def fit(self, labels, reserved_labels=None, min_freq=1):
        assert not self.__indices, "This {} instance has already fitted.".format(
            __name__
        )

        freq_table = collections.defaultdict(int)

        for label in labels:
            freq_table[label] += 1

        sorted_freq_table = sorted(freq_table.items(), key=lambda v: (-v[1], v[0]))

        if isinstance(reserved_labels, list):
            for label in reserved_labels:
                self.__values[len(self.__values)] = label

        for k, v in sorted_freq_table:
            if v >= min_freq:
                self.__values[len(self.__values)] = k

        self.__indices = {v: k for k, v in self.__values.items()}

    def transform(self, label, default=None):
        assert self.__indices, "This {} instance is not fitted yet.".format(__name__)
        return self.__indices.get(label, default)

    def inverse_transform(self, _id, default=None):
        assert self.__indices, "This {} instance is not fitted yet.".format(__name__)
        return self.__values.get(_id, default)

    @property
    def size(self):
        return len(self.__values)
