import { type Item } from "@shougo/ddu-vim/types";
import { BaseSource } from "@shougo/ddu-vim/source";
import { ActionData } from "../../@ddu-kinds/deol.ts";

import type { Denops } from "@denops/std";
import * as fn from "@denops/std/function";

type Params = {
  command: string[];
};

export class Source extends BaseSource<Params> {
  override kind = "deol";

  override gather(args: {
    denops: Denops;
    sourceParams: Params;
  }): ReadableStream<Item<ActionData>[]> {
    return new ReadableStream({
      async start(controller) {
        const items = Promise.all(
          [...Array(await fn.tabpagenr(args.denops, "$"))].map(
            async (_, i) => {
              const tabNr = i + 1;
              const cwd = await args.denops.call("deol#_get_cwd", tabNr) as
                | string
                | null;
              return {
                word: cwd ? `${cwd}` : `[new]`,
                action: {
                  command: args.sourceParams.command,
                  tabNr: tabNr,
                  existsDeol: Boolean(cwd),
                },
              };
            },
          ),
        );

        controller.enqueue(
          await items,
        );

        controller.close();
      },
    });
  }

  override params(): Params {
    return {
      command: [],
    };
  }
}
