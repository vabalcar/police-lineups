import { routerReducer } from "@ngrx/router-store";
import { ActionReducerMap } from "@ngrx/store";

import { authReducer } from "./auth/auth.reducer";
import { userUpdateReducer } from "./user-update/user-update.reducer";
import { usersListReducer } from "./users-list/users-list.reducer";

export const reducers: ActionReducerMap<Record<string, unknown>> = {
  router: routerReducer,
  auth: authReducer,
  usersList: usersListReducer,
  userUpdate: userUpdateReducer,
};
