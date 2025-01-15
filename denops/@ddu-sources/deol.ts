import { type Item } from "jsr:@shougo/ddu-vim@~9.4.0/types";
import { BaseSource } from "jsr:@shougo/ddu-vim@~9.4.0/source";
import { ActionData } from "../@ddu-kinds/deol.ts";

import type { Denops } from "jsr:@denops/core@~7.0.0";
import * as fn from "jsr:@denops/std@~7.4.0/function";

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
