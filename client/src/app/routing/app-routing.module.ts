import { NgModule } from "@angular/core";
import { Routes, RouterModule } from "@angular/router";

import { UserAuthGuard } from "./guards/auth-user/auth-user.guard";
import { AdminAuthGuard } from "./guards/auth-admin/auth-admin.guard";

import { LoginComponent } from "../components/pages/users/login/login.component";
import { NotFoundComponent } from "../components/pages/not-found/not-found.component";
import { PeopleComponent } from "../components/pages/people/people/people.component";
import { PersonComponent } from "../components/pages/people/person/person.component";
import { HomeComponent } from "../components/pages/home/home.component";
import { RegisterComponent } from "../components/pages/users/register/register.component";
import { ImportPersonComponent } from "../components/pages/people/import-person/import-person.component";
import { UserSettingsComponent } from "../components/pages/users/user-settings/user-settings.component";
import { UsersListComponent } from "../components/pages/users/users-list/users-list.component";
import { NotAuthorizedComponent } from "../components/pages/users/not-authorized/not-authorized.component";

const routes: Routes = [
  {
    path: "register",
    component: RegisterComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: "users",
    component: UsersListComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: "user/current",
    component: UserSettingsComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: "user/:userId",
    component: UserSettingsComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: "import",
    component: ImportPersonComponent,
    canActivate: [UserAuthGuard],
  },
  { path: "people", component: PeopleComponent, canActivate: [UserAuthGuard] },
  {
    path: "person/:id",
    component: PersonComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: "login",
    component: LoginComponent,
  },
  { path: "home", component: HomeComponent },
  { path: "", redirectTo: "/home", pathMatch: "full" },
  { path: "not-authorized", component: NotAuthorizedComponent },
  { path: "not-found", component: NotFoundComponent },
  { path: "**", component: NotFoundComponent },
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule],
})
export class AppRoutingModule {}
