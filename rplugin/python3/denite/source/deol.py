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
        candidates = []
        for tabnr in range(1, self.vim.call('tabpagenr', '$') + 1):
            deol = self.vim.call('gettabvar', tabnr, 'deol', {})
            candidates.append({
            'word': (
                '{}: {} ({})'.format(tabnr, deol['command'], deol['cwd'])
                if deol
                else '{}: [new denite]'.format(tabnr)),
            'action__command': command,
            'action__tabnr': tabnr,
            'action__is_deol': bool(deol),
        })
        return candidates


class Kind(BaseK):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'deol'
        self.default_action = 'switch'
        self.redraw_actions += ['delete']
        self.persist_actions += ['delete']

    def action_switch(self, context):
        target = context['targets'][0]
        self.vim.command(f"tabnext {target['action__tabnr']}")
        if not target['action__is_deol']:
            self.vim.command(f"Deol {target['action__command']}")

    def action_new(self, context):
        target = context['targets'][0]
        if not target['action__is_deol']:
            return

        self.vim.command(f"tabnext {target['action__tabnr']}")
        deol = self.vim.call('gettabvar',
                             target['action__tabnr'], 'deol')
        options = {'start_insert': deol['options']['start_insert']}
        if target['action__command']:
            options['command'] = target['action__command']
        self.vim.call('deol#new', options)

    def action_delete(self, context):
        for tabnr in reversed(sorted(
            [x['action__tabnr'] for x in context['targets']])):
            self.vim.command(f'silent! {tabnr} tabclose')

    def action_edit(self, context):
        target = context['targets'][0]
        if not target['action__is_deol']:
            return

        deol = self.vim.call('gettabvar',
                             target['action__tabnr'], 'deol')
        cwd = str(self.vim.call(
            'denite#util#input',
            f"New deol cwd: ", deol['cwd'], 'dir'
        ))

        if cwd == '':
            return

        if self.vim.call('isdirectory', cwd):
            self.vim.command(f"tabnext {target['action__tabnr']}")
            self.vim.call('deol#cd', cwd)
        else:
            self.vim.command('redraw')
            denite.util.error(self.vim, f'{cwd} is not directory.')
