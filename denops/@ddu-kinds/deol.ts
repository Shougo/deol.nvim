import {
  ActionArguments,
  ActionFlags,
  BaseKind,
  DduItem,
} from "https://deno.land/x/ddu_vim@v0.7.1/types.ts#^";
import { Denops, fn } from "https://deno.land/x/ddu_vim@v0.7.1/deps.ts";

export type ActionData = {
  command: string;
  tabNr: number;
  existsDeol: boolean;
};

type Params = Record<string, never>;

export class Kind extends BaseKind<Params> {
  actions: Record<
    string,
    (args: ActionArguments<Params>) => Promise<ActionFlags>
  > = {
    switch: async (args: { denops: Denops; items: DduItem[] }) => {
      for (const item of args.items) {
        const action = item?.action as ActionData;
        await args.denops.cmd(`tabnext ${action.tabNr}`);

        if (!action.existsDeol) {
          await args.denops.cmd(`Deol ${action.command}`);
        }
      }

      return Promise.resolve(ActionFlags.None);
    },
    new: async (args: { denops: Denops; items: DduItem[] }) => {
      for (const item of args.items) {
        const action = item?.action as ActionData;

        if (!action.existsDeol) {
          continue;
        }

        await args.denops.cmd(`tabnext ${action.tabNr}`);
        const deol =
          (await fn.gettabvar(args.denops, action.tabNr, "deol", null)) as {
          options: {
            "start_insert": boolean,
          };
        };
        const options = {
          "start_insert": deol.options.start_insert,
          command: action.command,
        };
        await args.denops.call("deol#new", options);
      }

      return Promise.resolve(ActionFlags.None);
    },
    delete: async (args: { denops: Denops; items: DduItem[] }) => {
      const currentTab = await fn.tabpagenr(args.denops);
      for (const item of args.items) {
        const action = item?.action as ActionData;

        // Skip current tab
        if (action.tabNr == currentTab) {
          continue;
        }

        await args.denops.cmd(`silent! tabclose ${action.tabNr}`);
      }

      return Promise.resolve(ActionFlags.Persist | ActionFlags.RefreshItems);
    },
  };

  params(): Params {
    return {};
  }
}
