import {
  Context,
  DdcOptions,
  Item,
  SourceOptions,
} from "jsr:@shougo/ddc-vim@~9.1.0/types";
import { BaseSource } from "jsr:@shougo/ddc-vim@~9.1.0/source";

import type { Denops } from "jsr:@denops/core@~7.0.0";

type Params = Record<string, never>;

export class Source extends BaseSource<Params> {
  override async gather(args: {
    denops: Denops;
    context: Context;
    options: DdcOptions;
    sourceOptions: SourceOptions;
    completeStr: string;
  }): Promise<Item[]> {
    const histories = await args.denops.call(
      "deol#_get_histories",
    ) as string[];
    const input = await args.denops.call("deol#get_input") as string;
    const inputLength = input.length - args.completeStr.length;
    const filterInput = input.substring(0, inputLength);
    return histories.reverse().filter((word) => word.startsWith(filterInput))
      .map((word) => ({ word: word.substring(inputLength) }));
  }

  override params(): Params {
    return {};
  }
}
