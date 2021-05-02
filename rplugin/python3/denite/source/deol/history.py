# ============================================================================
# FILE: deol_history.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from denite.kind.base import Base as BaseK
from denite.source.base import Base

import denite.util
import re
from pathlib import Path


class Source(Base):

    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol/history'
        self.kind = Kind(vim)

    def gather_candidates(self, context):
        if 'deol#shell_history_path' not in self.vim.vars:
            return []

        history_path = Path(denite.util.expand(
            self.vim.vars['deol#shell_history_path']))
        if not history_path.exists():
            return []

        candidates = []
        histories = history_path.read_text(
                encoding='utf-8', errors='replace').split('\n')
        for line in histories[: self.vim.vars['deol#shell_history_max']]:
            line = re.sub(r'^(\d+/)+[:0-9; ]+|^[:0-9; ]+', '', line)
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
