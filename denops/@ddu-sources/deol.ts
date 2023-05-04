import {
  BaseSource,
  Item,
} from "https://deno.land/x/ddu_vim@v2.8.3/types.ts";
import { Denops, fn } from "https://deno.land/x/ddu_vim@v2.8.3/deps.ts";
import { ActionData } from "../@ddu-kinds/deol.ts";

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
              const deol = (await args.denops.call("deol#_get", tabNr)) as {
                cwd: string;
              };
              return {
                word: (tabNr < 10 ? " " : "") + (deol
                  ? `${tabNr}: ${deol.cwd}`
                  : `${tabNr}: [new]`),
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
