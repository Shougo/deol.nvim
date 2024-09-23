import { type Item } from "jsr:@shougo/ddu-vim@~6.2.0/types";
import { BaseSource } from "jsr:@shougo/ddu-vim@~6.2.0/source";
import { ActionData } from "../@ddu-kinds/deol.ts";

import type { Denops } from "jsr:@denops/core@~7.0.0";
import * as fn from "jsr:@denops/std@~7.1.1/function";

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
              const deol = await args.denops.call("deol#_get", tabNr) as {
                cwd: string;
              };
              return {
                word: deol ? `${deol.cwd}` : `[new]`,
                action: {
                  command: args.sourceParams.command,
                  tabNr: tabNr,
                  existsDeol: Boolean(deol),
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
