# ============================================================================
# FILE: deol_history.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from denite.kind.base import Base as BaseK
from denite.source.base import Base

import denite.util
from pathlib import Path


class Source(Base):

    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol/history'
        self.kind = Kind(vim)

    def gather_candidates(self, context):
        candidates = []
        for line in reversed(self.vim.call('deol#_get_histories')):
            candidates.append({
                'word': line,
                'action__history': line,
            })
        return candidates


class Kind(BaseK):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol/history'
        self.default_action = 'execute'

    def action_execute(self, context):
        for target in context['targets']:
            self.vim.call('deol#send', target['action__history'])
