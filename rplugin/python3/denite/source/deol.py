# ============================================================================
# FILE: deol.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
# License: MIT license
# ============================================================================

from .base import Base
from ..kind.base import Base as BaseK

import denite.util


class Source(Base):

    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol'
        self.kind = Kind(vim)

    def gather_candidates(self, context):
        command = context['args'][0] if context['args'] else ''
        return [{
            'word': (
                '{}: {} ({})'.format(
                    x.number,
                    x.vars['deol']['command'],
                    x.vars['deol']['cwd'])
                if 'deol' in x.vars
                else '{}: [new denite]'.format(x.number)),
            'action__command': command,
            'action__tabnr': x.number,
            'action__is_deol': ('deol' in x.vars),
        } for x in self.vim.tabpages if x.valid]


class Kind(BaseK):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol'
        self.default_action = 'switch'
        self.redraw_actions += ['delete']
        self.persist_actions += ['delete']

    def action_switch(self, context):
        target = context['targets'][0]
        self.vim.command(
            'tabnext ' + str(target['action__tabnr']) +
            ('' if target['action__is_deol']
                else '| Deol ' + target['action__command']))

    def action_new(self, context):
        target = context['targets'][0]
        self.vim.command(str(target['action__tabnr']) + 'tabnext')
        options = {}
        if target['action__command']:
            options['command'] = target['action__command']
        self.vim.call('deol#new', options)

    def action_delete(self, context):
        target = context['targets'][0]
        tabnr = target['action__tabnr']
        if tabnr == self.vim.current.tabpage.number:
            return
        self.vim.command(str(tabnr) + 'tabclose')

    def action_edit(self, context):
        target = context['targets'][0]
        deol = self.vim.call('gettabvar',
                                target['action__tabnr'], 'deol')
        cwd = str(self.vim.call(
            'denite#util#input',
            f"New deol cwd: ", deol['cwd'], 'dir'
        ))

        if self.vim.call('isdirectory', cwd):
            self.vim.command(f"tabnext {target['action__tabnr']}")
            self.vim.call('deol#cd', cwd)
        else:
            self.vim.command('redraw')
            denite.util.error(self.vim, f'{cwd} is not directory.')
