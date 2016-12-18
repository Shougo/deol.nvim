# ============================================================================
# FILE: deol.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from .base import Base
from ..kind.command import Kind as Command


class Source(Base):

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'deol'
        self.kind = Kind(vim)

    def gather_candidates(self, context):
        return [{
            'word': (
                '{}: {} ({})'.format(
                    x.number,
                    x.vars['deol']['command'],
                    x.vars['deol']['cwd'])
                if 'deol' in x.vars
                else '{}: [new denite]'.format(x.number)),
            'action__tabnr': x.number,
            'action__command': (
                'tabnext ' + str(x.number) +
                ('' if 'deol' in x.vars else '| Deol'))}
                for x in self.vim.tabpages if x.valid]

class Kind(Command):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'command/deol'

    def action_new(self, context):
        target = context['targets'][0]
        self.vim.command(str(target['action__tabnr']) + 'tabnext')
        self.vim.call('deol#new', {})
