# ============================================================================
# FILE: deol.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from .base import Base


class Source(Base):

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'deol'
        self.kind = 'command'

    def gather_candidates(self, context):
        return [{
            'word': '{}: {} ({})'.format(
                x.number,
                x.vars['deol']['command'],
                x.vars['deol']['cwd']),
            'action__command': 'tabnext ' + str(x.number)}
                for x in self.vim.tabpages if x.valid and 'deol' in x.vars]
