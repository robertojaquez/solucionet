using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141008)]
	public class _202501141008_create_man_det_filtros_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_filtros_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}
