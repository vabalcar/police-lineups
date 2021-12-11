import { NgModule } from "@angular/core";
import { Routes, RouterModule } from "@angular/router";

import { PathTemplate, StaticPath } from "./path";

import { UserAuthGuard } from "./guards/auth-user/auth-user.guard";
import { AdminAuthGuard } from "./guards/auth-admin/auth-admin.guard";

import { LoginComponent } from "../components/pages/users/login/login.component";
import { PeopleComponent } from "../components/pages/people/people/people.component";
import { PersonComponent } from "../components/pages/people/person/person.component";
import { HomeComponent } from "../components/pages/home/home.component";
import { RegisterComponent } from "../components/pages/users/register/register.component";
import { ImportPersonComponent } from "../components/pages/people/import-person/import-person.component";
import { UserSettingsComponent } from "../components/pages/users/user-settings/user-settings.component";
import { UsersListComponent } from "../components/pages/users/users-list/users-list.component";
import { NotAuthorizedComponent } from "../components/pages/users/not-authorized/not-authorized.component";
import { NotFoundComponent } from "../components/pages/not-found/not-found.component";
import { PathNotFoundComponent } from "../components/pages/path-not-found/path-not-found.component";

const getPathForRoute = (path: StaticPath) => path.substring(1);

const routes: Routes = [
  {
    path: getPathForRoute(StaticPath.register),
    component: RegisterComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: getPathForRoute(StaticPath.users),
    component: UsersListComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: getPathForRoute(StaticPath.currentUser),
    component: UserSettingsComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: PathTemplate.user,
    component: UserSettingsComponent,
    canActivate: [AdminAuthGuard],
  },
  {
    path: getPathForRoute(StaticPath.import),
    component: ImportPersonComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: getPathForRoute(StaticPath.people),
    component: PeopleComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: PathTemplate.person,
    component: PersonComponent,
    canActivate: [UserAuthGuard],
  },
  {
    path: getPathForRoute(StaticPath.login),
    component: LoginComponent,
  },
  { path: getPathForRoute(StaticPath.home), component: HomeComponent },
  {
    path: getPathForRoute(StaticPath.default),
    redirectTo: StaticPath.home,
    pathMatch: "full",
  },
  {
    path: getPathForRoute(StaticPath.notAuthorized),
    component: NotAuthorizedComponent,
  },
  {
    path: getPathForRoute(StaticPath.notFound),
    component: NotFoundComponent,
  },
  {
    path: getPathForRoute(StaticPath.pathNotFound),
    component: PathNotFoundComponent,
  },
  { path: "**", component: PathNotFoundComponent },
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule],
})
export class AppRoutingModule {}
