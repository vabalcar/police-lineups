import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';

import { BASE_PATH } from './api/variables';

@NgModule({
  declarations: [
    AppComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule
  ],
  providers: [
    {provide: BASE_PATH, useFactory: () => {
      const serverConfig = require('../../../config/server.json');
      return `localhost:${serverConfig.port}`;
    }}
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
