import { Injectable } from "@angular/core";
import { Actions, createEffect, ofType } from "@ngrx/effects";
import { exhaustMap, map } from "rxjs/operators";
import { DefaultService } from "src/app/api/api/default.service";

import { convertToLocalDateTime } from "../../utils/date.utils";
import { catchBeError } from "../../utils/errors.utils";
import { loadPeopleList, peopleListLoaded } from "./people-list.actions";

@Injectable()
export class PeopleListEffects {
  loadPeopleList$ = createEffect(() =>
    this.actions$.pipe(
      ofType(loadPeopleList),
      exhaustMap(() =>
        this.api.getPeople().pipe(
          map((response) =>
            peopleListLoaded({
              people: response.map((person) => ({
                ...person,
                birthDate: convertToLocalDateTime(person.birthDate),
              })),
            })
          ),
          catchBeError()
        )
      )
    )
  );

  constructor(private actions$: Actions, private api: DefaultService) {}
}
