import {
  ActionArguments,
  ActionFlags,
  BaseKind,
  DduItem,
} from "https://deno.land/x/ddu_vim@v3.3.3/types.ts";
import { Denops, fn, op } from "https://deno.land/x/ddu_vim@v3.3.3/deps.ts";

export type ActionData = {
  command: string[];
  tabNr: number;
  existsDeol: boolean;
};

type Params = Record<string, never>;

export class Kind extends BaseKind<Params> {
  override actions: Record<
    string,
    (args: ActionArguments<Params>) => Promise<ActionFlags>
  > = {
    switch: async (args: { denops: Denops; items: DduItem[] }) => {
      for (const item of args.items) {
        const action = item?.action as ActionData;
        await args.denops.cmd(`tabnext ${action.tabNr}`);

        if (
          !action.existsDeol ||
          (await op.filetype.getLocal(args.denops)) === "deol"
        ) {
          await args.denops.cmd(`Deol ${action.command.join(" ")}`);
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
        const deol = (await args.denops.call("deol#_get", action.tabNr)) as {
          options: {
            "start_insert": boolean;
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
      const tabNrs = args.items
        .map((item) => (item?.action as ActionData)?.tabNr)
        .filter((tabNr) => tabNr !== undefined && tabNr != currentTab);

      for (const tabNr of tabNrs.sort().reverse()) {
        await args.denops.cmd(`silent! tabclose ${tabNr}`);
      }

      return Promise.resolve(ActionFlags.Persist | ActionFlags.RefreshItems);
    },
    edit: async (args: { denops: Denops; items: DduItem[] }) => {
      for (const item of args.items) {
        const action = item?.action as ActionData;
        const deol = (await args.denops.call("deol#_get", action.tabNr)) as {
          cwd: string;
        };

        if (!deol?.cwd) {
          continue;
        }

        const newCwd = await fn.input(
          args.denops,
          "New deol cwd: ",
          deol.cwd,
          "dir",
        );
        await args.denops.cmd("redraw");
        if (newCwd == "") {
          continue;
        }

        // Note: Deno.stat() may be failed
        try {
          const fileInfo = await Deno.stat(newCwd);

          if (fileInfo.isFile) {
            await args.denops.call(
              "ddu#util#print_error",
              `${newCwd} is not directory.`,
            );
            continue;
          }
        } catch (_e: unknown) {
          const result = await fn.confirm(
            args.denops,
            `${newCwd} is not directory.  Create?`,
            "&Yes\n&No\n&Cancel",
          );
          if (result != 1) {
            continue;
          }

          await fn.mkdir(args.denops, newCwd, "p");
        }

        await args.denops.cmd(`tabnext ${action.tabNr}`);

        // Move to deol buffer
        await args.denops.call("deol#start", "");

        await args.denops.call("deol#cd", newCwd);
      }

      return Promise.resolve(ActionFlags.None);
    },
  };

  override params(): Params {
    return {};
  }
}
